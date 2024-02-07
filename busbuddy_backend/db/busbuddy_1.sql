--
-- PostgreSQL database dump
--

-- Dumped from database version 13.11 (Debian 13.11-0+deb11u1)
-- Dumped by pg_dump version 13.11 (Debian 13.11-0+deb11u1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: bus_staff_role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.bus_staff_role AS ENUM (
    'driver',
    'collector'
);


ALTER TYPE public.bus_staff_role OWNER TO postgres;

--
-- Name: bus_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.bus_type AS ENUM (
    'normal',
    'mini',
    'double_decker'
);


ALTER TYPE public.bus_type OWNER TO postgres;

--
-- Name: feedback_subject; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.feedback_subject AS ENUM (
    'staff',
    'bus',
    'driver',
    'logistics',
    'other'
);


ALTER TYPE public.feedback_subject OWNER TO postgres;

--
-- Name: payment_method; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.payment_method AS ENUM (
    'bkash',
    'nagad',
    'sbl'
);


ALTER TYPE public.payment_method OWNER TO postgres;

--
-- Name: time_point; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.time_point AS (
	station character varying(32),
	"time" timestamp with time zone
);


ALTER TYPE public.time_point OWNER TO postgres;

--
-- Name: time_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.time_type AS ENUM (
    'morning',
    'afternoon',
    'evening'
);


ALTER TYPE public.time_type OWNER TO postgres;

--
-- Name: travel_direction; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.travel_direction AS ENUM (
    'from_buet',
    'to_buet'
);


ALTER TYPE public.travel_direction OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.admin (
    id character varying(32) NOT NULL,
    password character varying(64) NOT NULL
);


ALTER TABLE public.admin OWNER TO postgres;

--
-- Name: buet_staff; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buet_staff (
    id character varying(32) NOT NULL,
    name character varying(128) NOT NULL,
    department character varying(64) NOT NULL,
    designation character varying(256) NOT NULL,
    residence character varying(256),
    password character varying(64) NOT NULL
);


ALTER TABLE public.buet_staff OWNER TO postgres;

--
-- Name: student_feedback; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student_feedback (
    id bigint NOT NULL,
    complainer_id character varying(64) NOT NULL,
    route character varying,
    submission_timestamp timestamp with time zone NOT NULL,
    concerned_timestamp timestamp with time zone,
    subject public.feedback_subject NOT NULL,
    text text NOT NULL,
    trip_id bigint NOT NULL
);


ALTER TABLE public.student_feedback OWNER TO postgres;

--
-- Name: feedback_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.feedback_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.feedback_id_seq OWNER TO postgres;

--
-- Name: feedback_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.feedback_id_seq OWNED BY public.student_feedback.id;


--
-- Name: buet_staff_feedback; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buet_staff_feedback (
    id bigint DEFAULT nextval('public.feedback_id_seq'::regclass) NOT NULL,
    complainer_id character varying(64) NOT NULL,
    route character varying,
    submission_timestamp timestamp with time zone NOT NULL,
    concerned_timestamp timestamp with time zone,
    subject public.feedback_subject NOT NULL,
    text text NOT NULL,
    trip_id bigint NOT NULL
);


ALTER TABLE public.buet_staff_feedback OWNER TO postgres;

--
-- Name: bus; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bus (
    reg_id character varying(20) NOT NULL,
    type public.bus_type NOT NULL,
    capacity integer NOT NULL,
    CONSTRAINT capacity_min CHECK ((capacity >= 0)),
    CONSTRAINT numplate CHECK (((reg_id)::text ~ '^[A-Za-z0-9]+$'::text))
);


ALTER TABLE public.bus OWNER TO postgres;

--
-- Name: bus_staff; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bus_staff (
    id character varying(64) NOT NULL,
    phone character(11) NOT NULL,
    password character varying(64) NOT NULL,
    role public.bus_staff_role NOT NULL,
    CONSTRAINT phone_check CHECK ((phone ~ '[0-9]{11}'::text))
);


ALTER TABLE public.bus_staff OWNER TO postgres;

--
-- Name: feedback; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.feedback AS
 SELECT student_feedback.id,
    student_feedback.complainer_id,
    student_feedback.route,
    student_feedback.submission_timestamp,
    student_feedback.concerned_timestamp,
    student_feedback.subject,
    student_feedback.text
   FROM (public.student_feedback
     JOIN public.buet_staff_feedback USING (id, complainer_id, route, submission_timestamp, concerned_timestamp, subject, text));


ALTER TABLE public.feedback OWNER TO postgres;

--
-- Name: purchase; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.purchase (
    id bigint NOT NULL,
    buyer_id character varying(64) NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    payment_method public.payment_method NOT NULL,
    trxid character varying(32) NOT NULL,
    quantity integer NOT NULL
);


ALTER TABLE public.purchase OWNER TO postgres;

--
-- Name: purchase_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.purchase_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.purchase_id_seq OWNER TO postgres;

--
-- Name: purchase_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.purchase_id_seq OWNED BY public.purchase.id;


--
-- Name: requisition; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.requisition (
    id bigint NOT NULL,
    requestor_id character varying NOT NULL,
    source character varying NOT NULL,
    destitnation character varying NOT NULL,
    bus_type public.bus_type NOT NULL,
    subject character varying(512) NOT NULL,
    text text,
    "timestamp" timestamp with time zone NOT NULL,
    approved_by character varying(64)
);


ALTER TABLE public.requisition OWNER TO postgres;

--
-- Name: requisition_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.requisition_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.requisition_id_seq OWNER TO postgres;

--
-- Name: requisition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.requisition_id_seq OWNED BY public.requisition.id;


--
-- Name: route; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.route (
    id character varying(32) NOT NULL,
    terminal_point character varying(32) NOT NULL,
    points character varying(32)[] NOT NULL
);


ALTER TABLE public.route OWNER TO postgres;

--
-- Name: schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schedule (
    id bigint NOT NULL,
    start_timestamp timestamp with time zone NOT NULL,
    route character varying NOT NULL,
    time_type public.time_type NOT NULL,
    time_list public.time_point[] NOT NULL,
    travel_direction public.travel_direction NOT NULL
);


ALTER TABLE public.schedule OWNER TO postgres;

--
-- Name: station; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.station (
    id character varying NOT NULL,
    name character varying(128) NOT NULL,
    coords point,
    adjacent_points character varying(32)[]
);


ALTER TABLE public.station OWNER TO postgres;

--
-- Name: student; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student (
    id character(7) NOT NULL,
    phone character(11) NOT NULL,
    email character varying NOT NULL,
    password character varying(64) NOT NULL,
    default_route character varying,
    name character varying(128) NOT NULL,
    CONSTRAINT phone_check CHECK ((phone ~ '[0-9]{11}'::text))
);


ALTER TABLE public.student OWNER TO postgres;

--
-- Name: student_notification; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student_notification (
    id bigint NOT NULL,
    user_id character(7)[] NOT NULL,
    text text,
    "timestamp" timestamp with time zone NOT NULL,
    is_read boolean NOT NULL
);


ALTER TABLE public.student_notification OWNER TO postgres;

--
-- Name: student_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.student_notification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.student_notification_id_seq OWNER TO postgres;

--
-- Name: student_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.student_notification_id_seq OWNED BY public.student_notification.id;


--
-- Name: ticket; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ticket (
    id bigint NOT NULL,
    student_id character(7) NOT NULL,
    trip_id bigint NOT NULL,
    purchase_id bigint NOT NULL,
    is_used boolean DEFAULT false NOT NULL
);


ALTER TABLE public.ticket OWNER TO postgres;

--
-- Name: ticket_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ticket_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ticket_id_seq OWNER TO postgres;

--
-- Name: ticket_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ticket_id_seq OWNED BY public.ticket.id;


--
-- Name: upcoming_trip; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.upcoming_trip (
    id bigint,
    start_timestamp timestamp with time zone,
    route character varying,
    bus character varying(20) NOT NULL,
    is_default boolean NOT NULL,
    bus_staff character varying(64) NOT NULL,
    approved_by character varying(64) NOT NULL
)
INHERITS (public.schedule);


ALTER TABLE public.upcoming_trip OWNER TO postgres;

--
-- Name: trip; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trip (
    end_timestamp timestamp with time zone NOT NULL,
    start_location point NOT NULL,
    end_location point,
    path point[]
)
INHERITS (public.upcoming_trip);


ALTER TABLE public.trip OWNER TO postgres;

--
-- Name: upcoming_trip_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.upcoming_trip_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.upcoming_trip_id_seq OWNER TO postgres;

--
-- Name: upcoming_trip_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.upcoming_trip_id_seq OWNED BY public.upcoming_trip.id;


--
-- Name: purchase id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase ALTER COLUMN id SET DEFAULT nextval('public.purchase_id_seq'::regclass);


--
-- Name: requisition id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition ALTER COLUMN id SET DEFAULT nextval('public.requisition_id_seq'::regclass);


--
-- Name: student_feedback id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_feedback ALTER COLUMN id SET DEFAULT nextval('public.feedback_id_seq'::regclass);


--
-- Name: student_notification id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_notification ALTER COLUMN id SET DEFAULT nextval('public.student_notification_id_seq'::regclass);


--
-- Name: ticket id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket ALTER COLUMN id SET DEFAULT nextval('public.ticket_id_seq'::regclass);


--
-- Data for Name: admin; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.admin (id, password) FROM stdin;
\.


--
-- Data for Name: buet_staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buet_staff (id, name, department, designation, residence, password) FROM stdin;
\.


--
-- Data for Name: buet_staff_feedback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buet_staff_feedback (id, complainer_id, route, submission_timestamp, concerned_timestamp, subject, text, trip_id) FROM stdin;
\.


--
-- Data for Name: bus; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bus (reg_id, type, capacity) FROM stdin;
\.


--
-- Data for Name: bus_staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bus_staff (id, phone, password, role) FROM stdin;
\.


--
-- Data for Name: purchase; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.purchase (id, buyer_id, "timestamp", payment_method, trxid, quantity) FROM stdin;
\.


--
-- Data for Name: requisition; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.requisition (id, requestor_id, source, destitnation, bus_type, subject, text, "timestamp", approved_by) FROM stdin;
\.


--
-- Data for Name: route; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.route (id, terminal_point, points) FROM stdin;
1	Uttara	{1,2,3,4,5,6,7,8,9,10,11,70}
8	Mirpur 12	{64,65,66,67,68,69,70}
2	Malibag	{12,13,14,15,16,70}
3	Sanarpar	{17,18,19,20,21,22,23,24,25,26,70}
4	Badda	{27,28,29,30,31,32,33,34,35,70}
5	Mohammadpur	{36,37,38,39,40,70}
6	Mirpur 2	{41,42,43,44,45,46,47,48,49,70}
7	Airport	{50,51,52,53,54,55,56,57,58,59,60,61,62,63,70}
\.


--
-- Data for Name: schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schedule (id, start_timestamp, route, time_type, time_list, travel_direction) FROM stdin;
1	2023-08-25 12:55:00+06	2	morning	{"(12,\\"2023-08-25 12:55:00+06\\")","(13,\\"2023-08-25 12:57:00+06\\")","(14,\\"2023-08-25 12:59:00+06\\")","(15,\\"2023-08-25 13:01:00+06\\")","(16,\\"2023-08-25 13:03:00+06\\")","(70,\\"2023-08-25 13:15:00+06\\")"}	to_buet
2	2023-08-25 19:40:00+06	2	afternoon	{"(12,\\"2023-08-25 19:40:00+06\\")","(13,\\"2023-08-25 19:52:00+06\\")","(14,\\"2023-08-25 19:54:00+06\\")","(15,\\"2023-08-25 19:57:00+06\\")","(16,\\"2023-08-25 20:00:00+06\\")","(70,\\"2023-08-25 20:03:00+06\\")"}	from_buet
3	2023-08-25 23:30:00+06	2	evening	{"(12,\\"2023-08-25 23:30:00+06\\")","(13,\\"2023-08-25 23:42:00+06\\")","(14,\\"2023-08-25 23:45:00+06\\")","(15,\\"2023-08-25 23:48:00+06\\")","(16,\\"2023-08-25 23:51:00+06\\")","(70,\\"2023-08-25 23:54:00+06\\")"}	from_buet
4	2023-08-25 12:40:00+06	3	morning	{"(17,\\"2023-08-25 12:40:00+06\\")","(18,\\"2023-08-25 12:42:00+06\\")","(19,\\"2023-08-25 12:44:00+06\\")","(20,\\"2023-08-25 12:46:00+06\\")","(21,\\"2023-08-25 12:48:00+06\\")","(22,\\"2023-08-25 12:50:00+06\\")","(23,\\"2023-08-25 12:52:00+06\\")","(24,\\"2023-08-25 12:54:00+06\\")","(25,\\"2023-08-25 12:57:00+06\\")","(26,\\"2023-08-25 13:00:00+06\\")","(70,\\"2023-08-25 13:15:00+06\\")"}	to_buet
5	2023-08-25 19:40:00+06	3	afternoon	{"(17,\\"2023-08-25 19:40:00+06\\")","(18,\\"2023-08-25 19:55:00+06\\")","(19,\\"2023-08-25 19:58:00+06\\")","(20,\\"2023-08-25 20:00:00+06\\")","(21,\\"2023-08-25 20:02:00+06\\")","(22,\\"2023-08-25 20:04:00+06\\")","(23,\\"2023-08-25 20:06:00+06\\")","(24,\\"2023-08-25 20:08:00+06\\")","(25,\\"2023-08-25 20:10:00+06\\")","(26,\\"2023-08-25 20:12:00+06\\")","(70,\\"2023-08-25 20:14:00+06\\")"}	from_buet
6	2023-08-25 23:30:00+06	3	evening	{"(17,\\"2023-08-25 23:30:00+06\\")","(18,\\"2023-08-25 23:45:00+06\\")","(19,\\"2023-08-25 23:48:00+06\\")","(20,\\"2023-08-25 23:50:00+06\\")","(21,\\"2023-08-25 23:52:00+06\\")","(22,\\"2023-08-25 23:54:00+06\\")","(23,\\"2023-08-25 23:56:00+06\\")","(24,\\"2023-08-25 23:58:00+06\\")","(25,\\"2023-08-26 00:00:00+06\\")","(26,\\"2023-08-26 00:02:00+06\\")","(70,\\"2023-08-26 00:04:00+06\\")"}	from_buet
7	2023-08-25 12:40:00+06	4	morning	{"(27,\\"2023-08-25 12:40:00+06\\")","(28,\\"2023-08-25 12:42:00+06\\")","(29,\\"2023-08-25 12:44:00+06\\")","(30,\\"2023-08-25 12:46:00+06\\")","(31,\\"2023-08-25 12:50:00+06\\")","(32,\\"2023-08-25 12:52:00+06\\")","(33,\\"2023-08-25 12:54:00+06\\")","(34,\\"2023-08-25 12:58:00+06\\")","(35,\\"2023-08-25 13:00:00+06\\")","(70,\\"2023-08-25 13:10:00+06\\")"}	to_buet
8	2023-08-25 19:40:00+06	4	afternoon	{"(27,\\"2023-08-25 19:40:00+06\\")","(28,\\"2023-08-25 19:50:00+06\\")","(29,\\"2023-08-25 19:52:00+06\\")","(30,\\"2023-08-25 19:54:00+06\\")","(31,\\"2023-08-25 19:56:00+06\\")","(32,\\"2023-08-25 19:58:00+06\\")","(33,\\"2023-08-25 20:00:00+06\\")","(34,\\"2023-08-25 20:02:00+06\\")","(35,\\"2023-08-25 20:04:00+06\\")","(70,\\"2023-08-25 20:06:00+06\\")"}	from_buet
9	2023-08-25 23:30:00+06	4	evening	{"(27,\\"2023-08-25 23:30:00+06\\")","(28,\\"2023-08-25 23:40:00+06\\")","(29,\\"2023-08-25 23:42:00+06\\")","(30,\\"2023-08-25 23:44:00+06\\")","(31,\\"2023-08-25 23:46:00+06\\")","(32,\\"2023-08-25 23:48:00+06\\")","(33,\\"2023-08-25 23:50:00+06\\")","(34,\\"2023-08-25 23:52:00+06\\")","(35,\\"2023-08-25 23:54:00+06\\")","(70,\\"2023-08-25 23:56:00+06\\")"}	from_buet
10	2023-08-25 12:30:00+06	5	morning	{"(36,\\"2023-08-25 12:30:00+06\\")","(37,\\"2023-08-25 12:33:00+06\\")","(38,\\"2023-08-25 12:40:00+06\\")","(39,\\"2023-08-25 12:45:00+06\\")","(40,\\"2023-08-25 12:50:00+06\\")","(70,\\"2023-08-25 13:00:00+06\\")"}	to_buet
11	2023-08-25 19:40:00+06	5	afternoon	{"(36,\\"2023-08-25 19:40:00+06\\")","(37,\\"2023-08-25 19:50:00+06\\")","(38,\\"2023-08-25 19:55:00+06\\")","(39,\\"2023-08-25 20:00:00+06\\")","(40,\\"2023-08-25 20:07:00+06\\")","(70,\\"2023-08-25 20:10:00+06\\")"}	from_buet
12	2023-08-25 23:30:00+06	5	evening	{"(36,\\"2023-08-25 23:30:00+06\\")","(37,\\"2023-08-25 23:40:00+06\\")","(38,\\"2023-08-25 23:45:00+06\\")","(39,\\"2023-08-25 23:50:00+06\\")","(40,\\"2023-08-25 23:57:00+06\\")","(70,\\"2023-08-26 00:00:00+06\\")"}	from_buet
13	2023-08-25 12:40:00+06	6	morning	{"(41,\\"2023-08-25 12:40:00+06\\")","(42,\\"2023-08-25 12:42:00+06\\")","(43,\\"2023-08-25 12:45:00+06\\")","(44,\\"2023-08-25 12:47:00+06\\")","(45,\\"2023-08-25 12:49:00+06\\")","(46,\\"2023-08-25 12:51:00+06\\")","(47,\\"2023-08-25 12:52:00+06\\")","(48,\\"2023-08-25 12:53:00+06\\")","(49,\\"2023-08-25 12:54:00+06\\")","(70,\\"2023-08-25 13:10:00+06\\")"}	to_buet
14	2023-08-25 19:40:00+06	6	afternoon	{"(41,\\"2023-08-25 19:40:00+06\\")","(42,\\"2023-08-25 19:56:00+06\\")","(43,\\"2023-08-25 19:58:00+06\\")","(44,\\"2023-08-25 20:00:00+06\\")","(45,\\"2023-08-25 20:02:00+06\\")","(46,\\"2023-08-25 20:04:00+06\\")","(47,\\"2023-08-25 20:06:00+06\\")","(48,\\"2023-08-25 20:08:00+06\\")","(49,\\"2023-08-25 20:10:00+06\\")","(70,\\"2023-08-25 20:12:00+06\\")"}	from_buet
15	2023-08-25 23:30:00+06	6	evening	{"(41,\\"2023-08-25 23:30:00+06\\")","(42,\\"2023-08-25 23:46:00+06\\")","(43,\\"2023-08-25 23:48:00+06\\")","(44,\\"2023-08-25 23:50:00+06\\")","(45,\\"2023-08-25 23:52:00+06\\")","(46,\\"2023-08-25 23:54:00+06\\")","(47,\\"2023-08-25 23:56:00+06\\")","(48,\\"2023-08-25 23:58:00+06\\")","(49,\\"2023-08-26 00:00:00+06\\")","(70,\\"2023-08-26 00:02:00+06\\")"}	from_buet
16	2023-08-25 12:40:00+06	7	morning	{"(50,\\"2023-08-25 12:40:00+06\\")","(51,\\"2023-08-25 12:42:00+06\\")","(52,\\"2023-08-25 12:43:00+06\\")","(53,\\"2023-08-25 12:46:00+06\\")","(54,\\"2023-08-25 12:47:00+06\\")","(55,\\"2023-08-25 12:48:00+06\\")","(56,\\"2023-08-25 12:50:00+06\\")","(57,\\"2023-08-25 12:52:00+06\\")","(58,\\"2023-08-25 12:53:00+06\\")","(59,\\"2023-08-25 12:54:00+06\\")","(60,\\"2023-08-25 12:56:00+06\\")","(61,\\"2023-08-25 12:58:00+06\\")","(62,\\"2023-08-25 13:00:00+06\\")","(63,\\"2023-08-25 13:02:00+06\\")","(70,\\"2023-08-25 13:00:00+06\\")"}	to_buet
17	2023-08-25 19:40:00+06	7	afternoon	{"(50,\\"2023-08-25 19:40:00+06\\")","(51,\\"2023-08-25 19:48:00+06\\")","(52,\\"2023-08-25 19:50:00+06\\")","(53,\\"2023-08-25 19:52:00+06\\")","(54,\\"2023-08-25 19:54:00+06\\")","(55,\\"2023-08-25 19:56:00+06\\")","(56,\\"2023-08-25 19:58:00+06\\")","(57,\\"2023-08-25 20:00:00+06\\")","(58,\\"2023-08-25 20:02:00+06\\")","(59,\\"2023-08-25 20:04:00+06\\")","(60,\\"2023-08-25 20:06:00+06\\")","(61,\\"2023-08-25 20:08:00+06\\")","(62,\\"2023-08-25 20:10:00+06\\")","(63,\\"2023-08-25 20:12:00+06\\")","(70,\\"2023-08-25 20:14:00+06\\")"}	from_buet
18	2023-08-25 23:30:00+06	7	evening	{"(50,\\"2023-08-25 23:30:00+06\\")","(51,\\"2023-08-25 23:38:00+06\\")","(52,\\"2023-08-25 23:40:00+06\\")","(53,\\"2023-08-25 23:42:00+06\\")","(54,\\"2023-08-25 23:44:00+06\\")","(55,\\"2023-08-25 23:46:00+06\\")","(56,\\"2023-08-25 23:48:00+06\\")","(57,\\"2023-08-25 23:50:00+06\\")","(58,\\"2023-08-25 23:52:00+06\\")","(59,\\"2023-08-25 23:54:00+06\\")","(60,\\"2023-08-25 23:56:00+06\\")","(61,\\"2023-08-25 23:58:00+06\\")","(62,\\"2023-08-26 00:00:00+06\\")","(63,\\"2023-08-26 00:02:00+06\\")","(70,\\"2023-08-26 00:04:00+06\\")"}	from_buet
19	2023-08-25 12:15:00+06	1	morning	{"(1,\\"2023-08-25 12:15:00+06\\")","(2,\\"2023-08-25 12:18:00+06\\")","(3,\\"2023-08-25 12:20:00+06\\")","(4,\\"2023-08-25 12:23:00+06\\")","(5,\\"2023-08-25 12:26:00+06\\")","(6,\\"2023-08-25 12:29:00+06\\")","(7,\\"2023-08-25 12:49:00+06\\")","(8,\\"2023-08-25 12:51:00+06\\")","(9,\\"2023-08-25 12:53:00+06\\")","(10,\\"2023-08-25 12:55:00+06\\")","(11,\\"2023-08-25 12:58:00+06\\")","(70,\\"2023-08-25 13:05:00+06\\")"}	to_buet
20	2023-08-25 19:40:00+06	1	afternoon	{"(1,\\"2023-08-25 19:40:00+06\\")","(2,\\"2023-08-25 19:47:00+06\\")","(3,\\"2023-08-25 19:50:00+06\\")","(4,\\"2023-08-25 19:52:00+06\\")","(5,\\"2023-08-25 19:54:00+06\\")","(6,\\"2023-08-25 20:06:00+06\\")","(7,\\"2023-08-25 20:09:00+06\\")","(8,\\"2023-08-25 20:12:00+06\\")","(9,\\"2023-08-25 20:15:00+06\\")","(10,\\"2023-08-25 20:18:00+06\\")","(11,\\"2023-08-25 20:21:00+06\\")","(70,\\"2023-08-25 20:24:00+06\\")"}	from_buet
21	2023-08-25 23:30:00+06	1	evening	{"(1,\\"2023-08-25 23:30:00+06\\")","(2,\\"2023-08-25 23:37:00+06\\")","(3,\\"2023-08-25 23:40:00+06\\")","(4,\\"2023-08-25 23:42:00+06\\")","(5,\\"2023-08-25 23:44:00+06\\")","(6,\\"2023-08-25 23:56:00+06\\")","(7,\\"2023-08-25 23:59:00+06\\")","(8,\\"2023-08-26 00:02:00+06\\")","(9,\\"2023-08-26 00:05:00+06\\")","(10,\\"2023-08-26 00:08:00+06\\")","(11,\\"2023-08-26 00:11:00+06\\")","(70,\\"2023-08-26 00:14:00+06\\")"}	from_buet
22	2023-08-25 12:10:00+06	8	morning	{"(64,\\"2023-08-25 12:10:00+06\\")","(65,\\"2023-08-25 12:13:00+06\\")","(66,\\"2023-08-25 12:18:00+06\\")","(67,\\"2023-08-25 12:20:00+06\\")","(68,\\"2023-08-25 12:22:00+06\\")","(69,\\"2023-08-25 12:25:00+06\\")","(70,\\"2023-08-25 12:40:00+06\\")"}	to_buet
23	2023-08-25 19:40:00+06	8	afternoon	{"(64,\\"2023-08-25 19:40:00+06\\")","(65,\\"2023-08-25 19:55:00+06\\")","(66,\\"2023-08-25 19:58:00+06\\")","(67,\\"2023-08-25 20:01:00+06\\")","(68,\\"2023-08-25 20:04:00+06\\")","(69,\\"2023-08-25 20:07:00+06\\")","(70,\\"2023-08-25 20:10:00+06\\")"}	from_buet
24	2023-08-25 23:30:00+06	8	evening	{"(64,\\"2023-08-25 23:30:00+06\\")","(65,\\"2023-08-25 23:45:00+06\\")","(66,\\"2023-08-25 23:48:00+06\\")","(67,\\"2023-08-25 23:51:00+06\\")","(68,\\"2023-08-25 23:54:00+06\\")","(69,\\"2023-08-25 23:57:00+06\\")","(70,\\"2023-08-26 00:00:00+06\\")"}	from_buet
\.


--
-- Data for Name: station; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.station (id, name, coords, adjacent_points) FROM stdin;
1	College Gate	\N	\N
2	Station Road	\N	\N
3	Tongi Bazar	\N	\N
4	Abdullahpur	\N	\N
5	Uttara House Building	\N	\N
6	Azampur	\N	\N
7	Shaheen College	\N	\N
8	Old Airport 	\N	\N
9	Ellenbari	\N	\N
10	Aolad Hossian Market	\N	\N
11	Farmgate	\N	\N
12	Malibag Khidma Market	\N	\N
13	Khilgao Railgate	\N	\N
14	Basabo	\N	\N
15	Bouddho Mandir	\N	\N
16	Mugdapara	\N	\N
17	Sanarpar	\N	\N
18	Signboard	\N	\N
19	Saddam Market	\N	\N
20	Matuail Medical	\N	\N
21	Rayerbag	\N	\N
22	Shonir Akhra	\N	\N
23	Kajla	\N	\N
24	Jatrabari	\N	\N
25	Ittefak Mor	\N	\N
26	Arambag	\N	\N
27	Notun Bazar	\N	\N
28	Uttor Badda	\N	\N
29	Moddho Badda	\N	\N
30	Merul Badda	\N	\N
31	Rampura TV Gate	\N	\N
32	Rampura Bazar	\N	\N
33	Abul Hotel	\N	\N
34	Malibag Railgate	\N	\N
35	Mouchak	\N	\N
36	Tajmahal Road	\N	\N
37	Nazrul Islam Road	\N	\N
38	Shankar Bus Stand	\N	\N
39	Dhanmondi 15	\N	\N
40	Jhigatola	\N	\N
41	Mirpur 10	\N	\N
42	Mirpur 2	\N	\N
43	Mirpur 1	\N	\N
44	Mirpur Chinese	\N	\N
45	Ansar Camp	\N	\N
46	Bangla College	\N	\N
47	Kallyanpur	\N	\N
48	Shyamoli Hall	\N	\N
49	Shishumela	\N	\N
50	Rajlokkhi	\N	\N
51	Airport	\N	\N
52	Kaola	\N	\N
53	Khilkhet	\N	\N
54	Bishwaroad	\N	\N
55	Sheora Bazar	\N	\N
56	MES	\N	\N
57	Navy Headquarter	\N	\N
58	Kakoli	\N	\N
59	Chairman Bari	\N	\N
60	Mohakhali	\N	\N
61	Nabisco	\N	\N
62	Satrasta	\N	\N
63	Mogbazar	\N	\N
64	Mirpur 11	\N	\N
65	Pallabi Cinema Hall	\N	\N
66	Kazipara	\N	\N
67	Sheorapara	\N	\N
68	Agargaon	\N	\N
69	Taltola	\N	\N
70	BUET	\N	\N
\.


--
-- Data for Name: student; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student (id, phone, email, password, default_route, name) FROM stdin;
\.


--
-- Data for Name: student_feedback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_feedback (id, complainer_id, route, submission_timestamp, concerned_timestamp, subject, text, trip_id) FROM stdin;
\.


--
-- Data for Name: student_notification; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_notification (id, user_id, text, "timestamp", is_read) FROM stdin;
\.


--
-- Data for Name: ticket; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ticket (id, student_id, trip_id, purchase_id, is_used) FROM stdin;
\.


--
-- Data for Name: trip; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trip (id, start_timestamp, route, time_type, time_list, bus, is_default, bus_staff, approved_by, end_timestamp, start_location, end_location, path, travel_direction) FROM stdin;
\.


--
-- Data for Name: upcoming_trip; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.upcoming_trip (id, start_timestamp, route, time_type, time_list, bus, is_default, bus_staff, approved_by, travel_direction) FROM stdin;
\.


--
-- Name: feedback_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.feedback_id_seq', 1, false);


--
-- Name: purchase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.purchase_id_seq', 1, false);


--
-- Name: requisition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.requisition_id_seq', 1, false);


--
-- Name: student_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.student_notification_id_seq', 1, false);


--
-- Name: ticket_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ticket_id_seq', 1, false);


--
-- Name: upcoming_trip_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.upcoming_trip_id_seq', 1, false);


--
-- Name: admin admin_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin
    ADD CONSTRAINT admin_pkey PRIMARY KEY (id);


--
-- Name: buet_staff_feedback buet_staff_feedback_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buet_staff_feedback
    ADD CONSTRAINT buet_staff_feedback_pkey PRIMARY KEY (id);


--
-- Name: buet_staff buet_staff_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buet_staff
    ADD CONSTRAINT buet_staff_pkey PRIMARY KEY (id);


--
-- Name: bus bus_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bus
    ADD CONSTRAINT bus_pkey PRIMARY KEY (reg_id);


--
-- Name: bus_staff bus_staff_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bus_staff
    ADD CONSTRAINT bus_staff_pkey PRIMARY KEY (id);


--
-- Name: student email_check; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.student
    ADD CONSTRAINT email_check CHECK (((email)::text ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'::text)) NOT VALID;


--
-- Name: student_feedback feedback_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_feedback
    ADD CONSTRAINT feedback_pkey PRIMARY KEY (id);


--
-- Name: purchase purchase_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase
    ADD CONSTRAINT purchase_pkey PRIMARY KEY (id);


--
-- Name: purchase purchase_quantity_check; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.purchase
    ADD CONSTRAINT purchase_quantity_check CHECK ((quantity > 0)) NOT VALID;


--
-- Name: requisition requisition_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition
    ADD CONSTRAINT requisition_pkey PRIMARY KEY (id);


--
-- Name: route route_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.route
    ADD CONSTRAINT route_pkey PRIMARY KEY (id);


--
-- Name: schedule schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_pkey PRIMARY KEY (id);


--
-- Name: station station_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.station
    ADD CONSTRAINT station_pkey PRIMARY KEY (id);


--
-- Name: student_notification student_notification_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_notification
    ADD CONSTRAINT student_notification_pkey PRIMARY KEY (id);


--
-- Name: student student_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_pkey PRIMARY KEY (id);


--
-- Name: ticket ticket_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket
    ADD CONSTRAINT ticket_pkey PRIMARY KEY (id);


--
-- Name: trip trip_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip
    ADD CONSTRAINT trip_pkey PRIMARY KEY (id);


--
-- Name: upcoming_trip upcoming_trip_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.upcoming_trip
    ADD CONSTRAINT upcoming_trip_pkey PRIMARY KEY (id);


--
-- Name: buet_staff_feedback buet_staff_feedback_complainer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buet_staff_feedback
    ADD CONSTRAINT buet_staff_feedback_complainer_id_fkey FOREIGN KEY (complainer_id) REFERENCES public.buet_staff(id);


--
-- Name: buet_staff_feedback buet_staff_feedback_route_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buet_staff_feedback
    ADD CONSTRAINT buet_staff_feedback_route_fkey FOREIGN KEY (route) REFERENCES public.route(id) NOT VALID;


--
-- Name: buet_staff_feedback buet_staff_feedback_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buet_staff_feedback
    ADD CONSTRAINT buet_staff_feedback_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trip(id) NOT VALID;


--
-- Name: purchase purchase_buyer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase
    ADD CONSTRAINT purchase_buyer_id_fkey FOREIGN KEY (buyer_id) REFERENCES public.student(id);


--
-- Name: requisition requisition_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition
    ADD CONSTRAINT requisition_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.admin(id) NOT VALID;


--
-- Name: requisition requisition_requestor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition
    ADD CONSTRAINT requisition_requestor_id_fkey FOREIGN KEY (requestor_id) REFERENCES public.buet_staff(id) NOT VALID;


--
-- Name: schedule schedule_route_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_route_fkey FOREIGN KEY (route) REFERENCES public.route(id) NOT VALID;


--
-- Name: student_feedback student_feedback_complainer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_feedback
    ADD CONSTRAINT student_feedback_complainer_id_fkey FOREIGN KEY (complainer_id) REFERENCES public.student(id) NOT VALID;


--
-- Name: student_feedback student_feedback_route_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_feedback
    ADD CONSTRAINT student_feedback_route_fkey FOREIGN KEY (route) REFERENCES public.route(id) NOT VALID;


--
-- Name: student_feedback student_feedback_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_feedback
    ADD CONSTRAINT student_feedback_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trip(id) NOT VALID;


--
-- Name: ticket ticket_purchase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket
    ADD CONSTRAINT ticket_purchase_id_fkey FOREIGN KEY (purchase_id) REFERENCES public.purchase(id);


--
-- Name: ticket ticket_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket
    ADD CONSTRAINT ticket_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student(id);


--
-- Name: ticket ticket_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket
    ADD CONSTRAINT ticket_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trip(id);


--
-- Name: trip trip_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip
    ADD CONSTRAINT trip_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.admin(id) NOT VALID;


--
-- Name: trip trip_bus_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip
    ADD CONSTRAINT trip_bus_fkey FOREIGN KEY (bus) REFERENCES public.bus(reg_id) NOT VALID;


--
-- Name: trip trip_route_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip
    ADD CONSTRAINT trip_route_fkey FOREIGN KEY (route) REFERENCES public.route(id) NOT VALID;


--
-- Name: upcoming_trip upcoming_trip_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.upcoming_trip
    ADD CONSTRAINT upcoming_trip_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.admin(id) NOT VALID;


--
-- Name: upcoming_trip upcoming_trip_bus_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.upcoming_trip
    ADD CONSTRAINT upcoming_trip_bus_fkey FOREIGN KEY (bus) REFERENCES public.bus(reg_id) NOT VALID;


--
-- Name: upcoming_trip upcoming_trip_route_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.upcoming_trip
    ADD CONSTRAINT upcoming_trip_route_fkey FOREIGN KEY (route) REFERENCES public.route(id) NOT VALID;


--
-- PostgreSQL database dump complete
--

