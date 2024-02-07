--
-- PostgreSQL database dump
--

-- Dumped from database version 15.5 (Debian 15.5-0+deb12u1)
-- Dumped by pg_dump version 15.5 (Debian 15.5-0+deb12u1)

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
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


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
    'double_decker',
    'micro',
    'single_decker'
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
    'sbl',
    'shurjopay'
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

--
-- Name: approve_requisition(bigint, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.approve_requisition(IN req_id bigint, IN admin_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    request RECORD;
    newbus character varying;
    newstaff bigint;
BEGIN
    -- Fetch the requisition record
    SELECT * INTO request FROM requisition WHERE id = req_id;

    -- Select a random bus registration ID
    SELECT reg_id INTO newbus FROM bus WHERE type = request.bus_type ORDER BY random() LIMIT 1;

    -- Select a random bus staff ID
    SELECT id INTO newstaff FROM bus_staff ORDER BY random() LIMIT 1;

    -- Update the requisition to mark it as approved by the admin
    UPDATE requisition SET approved_by = admin_id WHERE id = req_id;

    -- Insert the approved trip into the upcoming_trip table
    INSERT INTO upcoming_trip(start_timestamp, bus, is_default, bus_staff, approved_by)
    VALUES (request.timestamp, newbus, false, newstaff, admin_id);
END;
$$;


ALTER PROCEDURE public.approve_requisition(IN req_id bigint, IN admin_id character varying) OWNER TO postgres;

--
-- Name: create_allocation(bigint, date, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.create_allocation(IN sched_id bigint, IN on_day date, IN bus_id character varying, IN driver_id character varying, IN helper_id character varying, IN admin_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    sta_info time_point[];  -- Define an array of time_point
    time_of_stoppage timestamptz;
    station_of_stoppage character varying;
    sched schedule;
BEGIN
    -- Fetch the schedule record
    SELECT * INTO sched FROM schedule WHERE id = sched_id; -- Adjust the WHERE clause as needed

    -- Iterate over the time_list and populate the sta_info array
    FOR i IN 1 .. array_length(sched.time_list, 1) LOOP
        time_of_stoppage := generate_future_timestamp(sched.time_list[i].time, on_day);
        station_of_stoppage := sched.time_list[i].station;
        sta_info[i] := ROW(station_of_stoppage, time_of_stoppage)::time_point;
    END LOOP;

    -- Insert the data into the allocation table
    INSERT INTO allocation( start_timestamp,                           route,       time_type,        time_list,bus,    is_default, driver    ,approved_by,travel_direction, helper
    ) VALUES (generate_future_timestamp(sched.start_timestamp, on_day),sched.route, sched.time_type,  sta_info, bus_id, true,       driver_id, admin_id,   sched.travel_direction, helper_id);
END;
$$;


ALTER PROCEDURE public.create_allocation(IN sched_id bigint, IN on_day date, IN bus_id character varying, IN driver_id character varying, IN helper_id character varying, IN admin_id character varying) OWNER TO postgres;

--
-- Name: dummy_schedule(character varying, character varying[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.dummy_schedule(IN routeid character varying, IN stationids character varying[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    timepoints_array time_point[];
    size_of_schedule integer;
    stationId character varying;
BEGIN
    -- Initialize an empty array
    timepoints_array := '{}';

    -- Generate and insert timepoints
    FOREACH stationId IN ARRAY stationIds
    LOOP
        -- Append a new timepoint to the array for each station
        timepoints_array := timepoints_array || ARRAY[ROW(stationId, NOW())::time_point];
    END LOOP;

    SELECT COUNT(*) INTO size_of_schedule FROM schedule;

    size_of_schedule := ((size_of_schedule::integer) + 1)::character varying;
    INSERT INTO schedule(id,                start_timestamp,route,  time_type,  time_list, travel_direction) 
    VALUES              (size_of_schedule,  NOW()          ,routeID,'morning',  timepoints_array, 'to_buet');

    size_of_schedule := ((size_of_schedule::integer) + 1)::character varying;
    INSERT INTO schedule(id,                start_timestamp,route,  time_type,  time_list, travel_direction) 
    VALUES              (size_of_schedule,  NOW()         ,routeID,'afternoon',  timepoints_array, 'from_buet');

    size_of_schedule := ((size_of_schedule::integer) + 1)::character varying;
    INSERT INTO schedule(id,                start_timestamp,route,  time_type,  time_list, travel_direction) 
    VALUES              (size_of_schedule,  NOW()          ,routeID,'evening',  timepoints_array, 'from_buet');
END;
$$;


ALTER PROCEDURE public.dummy_schedule(IN routeid character varying, IN stationids character varying[]) OWNER TO postgres;

--
-- Name: generate_future_timestamp(timestamp with time zone, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_future_timestamp(input_timestamp timestamp with time zone, on_day date) RETURNS timestamp with time zone
    LANGUAGE plpgsql
    AS $$
	DECLARE
		current_t timestamptz;
	BEGIN
		-- Extract the time of day from the input timestamp

		-- Get the current date
		current_t := on_day::timestamptz;
		
		current_t := current_t + EXTRACT(HOUR FROM input_timestamp) * INTERVAL '1 HOUR';
        current_t := current_t + EXTRACT(MINUTE FROM input_timestamp) * INTERVAL '1 MINUTE';
-- 		current_t := current_t - 6 * INTERVAL '1 HOUR';
-- 		current_t := current_t AT TIME ZONE 'UTC+06';
		
		-- Combine the current date and extracted time to form the future timestamp
		RETURN current_t;
	END;
$$;


ALTER FUNCTION public.generate_future_timestamp(input_timestamp timestamp with time zone, on_day date) OWNER TO postgres;

--
-- Name: initiate_trip(bigint, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.initiate_trip(IN id_to_move bigint, IN driver_id character varying)
    LANGUAGE plpgsql
    AS $$
  -- Declare variables to store record data
  DECLARE
    record_data record;

  -- Fetch the record from table1
  
BEGIN
  SELECT * INTO record_data FROM allocation WHERE id = id_to_move;
    IF record_data.driver = driver_id THEN
        INSERT INTO trip( id,start_timestamp,route,time_type,time_list,travel_direction,bus,is_default,driver,approved_by,is_live,helper)  -- Specify column names
            VALUES (record_data.id,CURRENT_TIMESTAMP,record_data.route,record_data.time_type,record_data.time_list,record_data.travel_direction,record_data.bus,record_data.is_default,record_data.driver,record_data.approved_by,TRUE,record_data.helper);

    ELSE
        RAISE NOTICE 'driver id does not match';
    END IF;
  -- Insert the fetched record into table2
  
  -- Delete the record from table1
  DELETE FROM allocation WHERE id = id_to_move;
  
  -- Commit the transaction
--   COMMIT;
END;
$$;


ALTER PROCEDURE public.initiate_trip(IN id_to_move bigint, IN driver_id character varying) OWNER TO postgres;

--
-- Name: initiate_trip2(bigint, character varying, point); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.initiate_trip2(IN id_to_move bigint, IN driver_id character varying, IN start_loc point)
    LANGUAGE plpgsql
    AS $$
  -- Declare variables to store record data
  DECLARE
    record_data record;

  -- Fetch the record from table1
  
BEGIN
  SELECT * INTO record_data FROM allocation WHERE id = id_to_move;
    IF record_data.driver = driver_id THEN
        INSERT INTO trip( id,start_timestamp,route,time_type,time_list,travel_direction,bus,is_default,driver,approved_by,is_live,helper,start_location)  -- Specify column names
            VALUES (record_data.id,CURRENT_TIMESTAMP,record_data.route,record_data.time_type,record_data.time_list,record_data.travel_direction,record_data.bus,record_data.is_default,record_data.driver,record_data.approved_by,TRUE,record_data.helper,start_loc);

    ELSE
        RAISE NOTICE 'driver id does not match';
    END IF;
  -- Insert the fetched record into table2
  
  -- Delete the record from table1
  DELETE FROM allocation WHERE id = id_to_move;
  
  -- Commit the transaction
--   COMMIT;
END;
$$;


ALTER PROCEDURE public.initiate_trip2(IN id_to_move bigint, IN driver_id character varying, IN start_loc point) OWNER TO postgres;

--
-- Name: make_purchase(character varying, public.payment_method, character varying, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.make_purchase(IN stu_id character varying, IN p_method public.payment_method, IN trx_id character varying, IN cnt integer)
    LANGUAGE plpgsql
    AS $$
	DECLARE
		purchase_id bigint;
	BEGIN
		INSERT INTO purchase(buyer_id, timestamp, payment_method, trxid, quantity) 
		VALUES (stu_id, current_timestamp, p_method, trx_id, cnt) RETURNING id INTO purchase_id;
		
		for i in 1..cnt LOOP
			INSERT INTO ticket(student_id, trip_id, purchase_id, is_used)
			VALUES (stu_id, null, purchase_id, false);
		END LOOP;
		
	END;
$$;


ALTER PROCEDURE public.make_purchase(IN stu_id character varying, IN p_method public.payment_method, IN trx_id character varying, IN cnt integer) OWNER TO postgres;

--
-- Name: make_requisition(character varying, character varying, character varying, public.bus_type[], character varying, text, timestamp without time zone); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.make_requisition(IN req_id character varying, IN src character varying, IN dest character varying, IN bustype public.bus_type[], IN subj character varying, IN txt text, IN tstamp timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
	DECLARE
	BEGIN
		INSERT INTO requisition(requestor_id, source, destination, bus_type, subject, text, timestamp, approved_by) 
		VALUES (req_id, src, dest, bustype, subj, txt, tstamp, null);
		
	END;
$$;


ALTER PROCEDURE public.make_requisition(IN req_id character varying, IN src character varying, IN dest character varying, IN bustype public.bus_type[], IN subj character varying, IN txt text, IN tstamp timestamp without time zone) OWNER TO postgres;

--
-- Name: update_allocation(date, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.update_allocation(IN on_day date, IN admin_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    schedule_record schedule;
    driver_for_day character varying[];
    helper_for_day character varying[];
    bus_for_day character varying[];
    i integer;
    j integer;
	routeCnt integer;
BEGIN
    -- Populate staff_for_day array with routeCnt random driver IDs
	SELECT COUNT(*) into routeCnt from route;
	-- RAISE NOTICE 'routeCnt %', routeCnt;
    SELECT ARRAY(SELECT id FROM bus_staff WHERE role = 'driver' ORDER BY random() LIMIT routeCnt) INTO driver_for_day;
    SELECT ARRAY(SELECT id FROM bus_staff WHERE role = 'collector' ORDER BY random() LIMIT routeCnt) INTO helper_for_day;
	
    -- Populate bus_for_day array with routeCnt random bus registration IDs
    SELECT ARRAY(SELECT reg_id FROM bus ORDER BY random() LIMIT routeCnt) INTO bus_for_day;

    j := 0;
    i := 1;
    FOR schedule_record IN SELECT * FROM schedule LOOP
        -- Call the create_upcoming_trip procedure for each schedule record
        CALL create_allocation(schedule_record.id, on_day, bus_for_day[i], driver_for_day[i], helper_for_day[i], admin_id);

        j := j+1;

        if j = 3 THEN
            j :=0;
            i := i+1;
        END IF;

        -- Exit the loop after processing 24 records
        -- IF i = 8 THEN
        --     EXIT;
        -- END IF;
    END LOOP;
END;
$$;


ALTER PROCEDURE public.update_allocation(IN on_day date, IN admin_id character varying) OWNER TO postgres;

--
-- Name: update_upcoming_trip(date, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.update_upcoming_trip(IN on_day date, IN admin_id character varying)
    LANGUAGE plpgsql
    AS $$
	DECLARE
		schedule_record schedule;
		staff_for_day character varying[];
		bus_for_day character varying[];
		i integer;
		j integer;
		k integer;
	BEGIN
		staff_for_day := ARRAY(SELECT id FROM bus_staff WHERE role='driver' ORDER BY random() LIMIT 8);
		bus_for_day := ARRAY(SELECT reg_id FROM bus ORDER BY random() LIMIT 8);
		
		i := 1;
		j := 1;
		k := 1;
		FOR schedule_record IN SELECT * FROM schedule LOOP
			CALL create_upcoming_trip(schedule_record.id,on_day,bus_for_day[i],
									 staff_for_day[i],admin_id);
			--RAISE NOTICE '% %', staff_for_day[i], bus_for_day[i];
			j := j + 1;
			k := k + 1;
			if k>24 THEN
				EXIT;
			END IF;
			IF j > 3 THEN
				i := i+1;
				j := 1;
			END IF;
		END LOOP;
		
	END;
$$;


ALTER PROCEDURE public.update_upcoming_trip(IN on_day date, IN admin_id character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.admin (
    id character varying(32) NOT NULL,
    password character varying(64) NOT NULL,
    email character varying,
    photo character varying
);


ALTER TABLE public.admin OWNER TO postgres;

--
-- Name: allocation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.allocation (
    id bigint NOT NULL,
    start_timestamp timestamp with time zone,
    route character varying,
    time_type public.time_type,
    time_list public.time_point[],
    travel_direction public.travel_direction,
    bus character varying(20),
    is_default boolean,
    driver character varying(64),
    approved_by character varying(64),
    is_done boolean DEFAULT false,
    helper character varying
);


ALTER TABLE public.allocation OWNER TO postgres;

--
-- Name: buet_staff; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buet_staff (
    id character varying(32) NOT NULL,
    name character varying(128) NOT NULL,
    department character varying(64) NOT NULL,
    designation character varying(256) NOT NULL,
    residence character varying(256),
    password character varying(64) NOT NULL,
    phone character(11)
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
    text text NOT NULL,
    trip_id bigint,
    subject public.feedback_subject[] NOT NULL,
    response text
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
    text text NOT NULL,
    trip_id bigint,
    subject public.feedback_subject[] NOT NULL,
    response text
);


ALTER TABLE public.buet_staff_feedback OWNER TO postgres;

--
-- Name: bus; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bus (
    reg_id character varying(20) NOT NULL,
    type public.bus_type NOT NULL,
    capacity integer NOT NULL,
    remarks character varying,
    CONSTRAINT capacity_min CHECK ((capacity >= 0))
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
    name character varying(128) NOT NULL,
    CONSTRAINT phone_check CHECK ((phone ~ '[0-9]{11}'::text))
);


ALTER TABLE public.bus_staff OWNER TO postgres;

--
-- Name: inventory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory (
    id character varying NOT NULL,
    name character varying,
    amount integer,
    rate double precision
);


ALTER TABLE public.inventory OWNER TO postgres;

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
    source character varying,
    destination character varying NOT NULL,
    subject character varying(512) NOT NULL,
    text text,
    "timestamp" timestamp with time zone NOT NULL,
    approved_by character varying(64),
    bus_type public.bus_type[]
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
    points character varying(32)[]
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
-- Name: session; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session (
    sid character varying NOT NULL,
    sess json NOT NULL,
    expire timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.session OWNER TO postgres;

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
    default_station character varying,
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
    student_id character(7) NOT NULL,
    trip_id bigint,
    purchase_id bigint NOT NULL,
    is_used boolean DEFAULT false NOT NULL,
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL
);


ALTER TABLE public.ticket OWNER TO postgres;

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

ALTER SEQUENCE public.upcoming_trip_id_seq OWNED BY public.allocation.id;


--
-- Name: trip; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trip (
    id bigint DEFAULT nextval('public.upcoming_trip_id_seq'::regclass) NOT NULL,
    start_timestamp timestamp with time zone NOT NULL,
    route character varying,
    time_type public.time_type,
    time_list public.time_point[],
    travel_direction public.travel_direction,
    bus character varying(20) NOT NULL,
    is_default boolean NOT NULL,
    driver character varying(64) NOT NULL,
    approved_by character varying(64),
    end_timestamp timestamp with time zone,
    start_location point,
    end_location point,
    path point[],
    is_live boolean NOT NULL,
    passenger_count integer DEFAULT 0 NOT NULL,
    helper character varying
);


ALTER TABLE public.trip OWNER TO postgres;

--
-- Name: allocation id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.allocation ALTER COLUMN id SET DEFAULT nextval('public.upcoming_trip_id_seq'::regclass);


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
-- Data for Name: admin; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.admin (id, password, email, photo) FROM stdin;
nazmul	password	\N	\N
reyazul	123rxl	kazireyazulhasan@gmail.com	https://i.postimg.cc/wvrLNPxH/dp1.png
mubasshira	1905088	mubasshira31@gmail.com	https://i.postimg.cc/3wknczS4/mubash.png
mashroor	1905069	mashroor184@gmail.com	https://i.postimg.cc/tJn10N0z/IMG-20221028-093424.jpg
\.


--
-- Data for Name: allocation; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.allocation (id, start_timestamp, route, time_type, time_list, travel_direction, bus, is_default, driver, approved_by, is_done, helper) FROM stdin;
1925	2024-01-30 19:40:00+06	2	afternoon	{"(12,\\"2024-01-30 19:40:00+06\\")","(13,\\"2024-01-30 19:52:00+06\\")","(14,\\"2024-01-30 19:54:00+06\\")","(15,\\"2024-01-30 19:57:00+06\\")","(16,\\"2024-01-30 20:00:00+06\\")","(70,\\"2024-01-30 20:03:00+06\\")"}	from_buet	Ba-22-4326	t	arif43	\N	f	jamal7898
1926	2024-01-30 23:30:00+06	2	evening	{"(12,\\"2024-01-30 23:30:00+06\\")","(13,\\"2024-01-30 23:42:00+06\\")","(14,\\"2024-01-30 23:45:00+06\\")","(15,\\"2024-01-30 23:48:00+06\\")","(16,\\"2024-01-30 23:51:00+06\\")","(70,\\"2024-01-30 23:54:00+06\\")"}	from_buet	Ba-22-4326	t	arif43	\N	f	jamal7898
1927	2024-01-30 12:40:00+06	3	morning	{"(17,\\"2024-01-30 12:40:00+06\\")","(18,\\"2024-01-30 12:42:00+06\\")","(19,\\"2024-01-30 12:44:00+06\\")","(20,\\"2024-01-30 12:46:00+06\\")","(21,\\"2024-01-30 12:48:00+06\\")","(22,\\"2024-01-30 12:50:00+06\\")","(23,\\"2024-01-30 12:52:00+06\\")","(24,\\"2024-01-30 12:54:00+06\\")","(25,\\"2024-01-30 12:57:00+06\\")","(26,\\"2024-01-30 13:00:00+06\\")","(70,\\"2024-01-30 13:15:00+06\\")"}	to_buet	Ba-97-6734	t	altaf78	\N	f	abdulbari4
1928	2024-01-30 19:40:00+06	3	afternoon	{"(17,\\"2024-01-30 19:40:00+06\\")","(18,\\"2024-01-30 19:55:00+06\\")","(19,\\"2024-01-30 19:58:00+06\\")","(20,\\"2024-01-30 20:00:00+06\\")","(21,\\"2024-01-30 20:02:00+06\\")","(22,\\"2024-01-30 20:04:00+06\\")","(23,\\"2024-01-30 20:06:00+06\\")","(24,\\"2024-01-30 20:08:00+06\\")","(25,\\"2024-01-30 20:10:00+06\\")","(26,\\"2024-01-30 20:12:00+06\\")","(70,\\"2024-01-30 20:14:00+06\\")"}	from_buet	Ba-97-6734	t	altaf78	\N	f	abdulbari4
1929	2024-01-30 23:30:00+06	3	evening	{"(17,\\"2024-01-30 23:30:00+06\\")","(18,\\"2024-01-30 23:45:00+06\\")","(19,\\"2024-01-30 23:48:00+06\\")","(20,\\"2024-01-30 23:50:00+06\\")","(21,\\"2024-01-30 23:52:00+06\\")","(22,\\"2024-01-30 23:54:00+06\\")","(23,\\"2024-01-30 23:56:00+06\\")","(24,\\"2024-01-30 23:58:00+06\\")","(25,\\"2024-01-30 00:00:00+06\\")","(26,\\"2024-01-30 00:02:00+06\\")","(70,\\"2024-01-30 00:04:00+06\\")"}	from_buet	Ba-97-6734	t	altaf78	\N	f	abdulbari4
1932	2024-01-30 23:30:00+06	4	evening	{"(27,\\"2024-01-30 23:30:00+06\\")","(28,\\"2024-01-30 23:40:00+06\\")","(29,\\"2024-01-30 23:42:00+06\\")","(30,\\"2024-01-30 23:44:00+06\\")","(31,\\"2024-01-30 23:46:00+06\\")","(32,\\"2024-01-30 23:48:00+06\\")","(33,\\"2024-01-30 23:50:00+06\\")","(34,\\"2024-01-30 23:52:00+06\\")","(35,\\"2024-01-30 23:54:00+06\\")","(70,\\"2024-01-30 23:56:00+06\\")"}	from_buet	Ba-83-8014	t	rafiqul	\N	f	mahmud64
1934	2024-01-30 19:40:00+06	5	afternoon	{"(36,\\"2024-01-30 19:40:00+06\\")","(37,\\"2024-01-30 19:50:00+06\\")","(38,\\"2024-01-30 19:55:00+06\\")","(39,\\"2024-01-30 20:00:00+06\\")","(40,\\"2024-01-30 20:07:00+06\\")","(70,\\"2024-01-30 20:10:00+06\\")"}	from_buet	Ba-77-7044	t	rashed3	\N	f	reyazul
1935	2024-01-30 23:30:00+06	5	evening	{"(36,\\"2024-01-30 23:30:00+06\\")","(37,\\"2024-01-30 23:40:00+06\\")","(38,\\"2024-01-30 23:45:00+06\\")","(39,\\"2024-01-30 23:50:00+06\\")","(40,\\"2024-01-30 23:57:00+06\\")","(70,\\"2024-01-30 00:00:00+06\\")"}	from_buet	Ba-77-7044	t	rashed3	\N	f	reyazul
1936	2024-01-30 12:40:00+06	6	morning	{"(41,\\"2024-01-30 12:40:00+06\\")","(42,\\"2024-01-30 12:42:00+06\\")","(43,\\"2024-01-30 12:45:00+06\\")","(44,\\"2024-01-30 12:47:00+06\\")","(45,\\"2024-01-30 12:49:00+06\\")","(46,\\"2024-01-30 12:51:00+06\\")","(47,\\"2024-01-30 12:52:00+06\\")","(48,\\"2024-01-30 12:53:00+06\\")","(49,\\"2024-01-30 12:54:00+06\\")","(70,\\"2024-01-30 13:10:00+06\\")"}	to_buet	Ba-48-5757	t	shahid88	\N	f	alamgir
1937	2024-01-30 19:40:00+06	6	afternoon	{"(41,\\"2024-01-30 19:40:00+06\\")","(42,\\"2024-01-30 19:56:00+06\\")","(43,\\"2024-01-30 19:58:00+06\\")","(44,\\"2024-01-30 20:00:00+06\\")","(45,\\"2024-01-30 20:02:00+06\\")","(46,\\"2024-01-30 20:04:00+06\\")","(47,\\"2024-01-30 20:06:00+06\\")","(48,\\"2024-01-30 20:08:00+06\\")","(49,\\"2024-01-30 20:10:00+06\\")","(70,\\"2024-01-30 20:12:00+06\\")"}	from_buet	Ba-48-5757	t	shahid88	\N	f	alamgir
1938	2024-01-30 23:30:00+06	6	evening	{"(41,\\"2024-01-30 23:30:00+06\\")","(42,\\"2024-01-30 23:46:00+06\\")","(43,\\"2024-01-30 23:48:00+06\\")","(44,\\"2024-01-30 23:50:00+06\\")","(45,\\"2024-01-30 23:52:00+06\\")","(46,\\"2024-01-30 23:54:00+06\\")","(47,\\"2024-01-30 23:56:00+06\\")","(48,\\"2024-01-30 23:58:00+06\\")","(49,\\"2024-01-30 00:00:00+06\\")","(70,\\"2024-01-30 00:02:00+06\\")"}	from_buet	Ba-48-5757	t	shahid88	\N	f	alamgir
1970	2024-02-01 19:40:00+06	8	afternoon	{"(64,\\"2024-02-01 19:40:00+06\\")","(65,\\"2024-02-01 19:55:00+06\\")","(66,\\"2024-02-01 19:58:00+06\\")","(67,\\"2024-02-01 20:01:00+06\\")","(68,\\"2024-02-01 20:04:00+06\\")","(69,\\"2024-02-01 20:07:00+06\\")","(70,\\"2024-02-01 20:10:00+06\\")"}	from_buet	Ba-36-1921	t	nizam88	nazmul	f	azim990
1971	2024-02-01 23:30:00+06	8	evening	{"(64,\\"2024-02-01 23:30:00+06\\")","(65,\\"2024-02-01 23:45:00+06\\")","(66,\\"2024-02-01 23:48:00+06\\")","(67,\\"2024-02-01 23:51:00+06\\")","(68,\\"2024-02-01 23:54:00+06\\")","(69,\\"2024-02-01 23:57:00+06\\")","(70,\\"2024-02-01 00:00:00+06\\")"}	from_buet	Ba-36-1921	t	nizam88	nazmul	f	mahbub777
1942	2024-01-30 12:15:00+06	1	morning	{"(1,\\"2024-01-30 12:15:00+06\\")","(2,\\"2024-01-30 12:18:00+06\\")","(3,\\"2024-01-30 12:20:00+06\\")","(4,\\"2024-01-30 12:23:00+06\\")","(5,\\"2024-01-30 12:26:00+06\\")","(6,\\"2024-01-30 12:29:00+06\\")","(7,\\"2024-01-30 12:49:00+06\\")","(8,\\"2024-01-30 12:51:00+06\\")","(9,\\"2024-01-30 12:53:00+06\\")","(10,\\"2024-01-30 12:55:00+06\\")","(11,\\"2024-01-30 12:58:00+06\\")","(70,\\"2024-01-30 13:05:00+06\\")"}	to_buet	Ba-93-6087	t	abdulkarim6	\N	f	zahir53
1943	2024-01-30 19:40:00+06	1	afternoon	{"(1,\\"2024-01-30 19:40:00+06\\")","(2,\\"2024-01-30 19:47:00+06\\")","(3,\\"2024-01-30 19:50:00+06\\")","(4,\\"2024-01-30 19:52:00+06\\")","(5,\\"2024-01-30 19:54:00+06\\")","(6,\\"2024-01-30 20:06:00+06\\")","(7,\\"2024-01-30 20:09:00+06\\")","(8,\\"2024-01-30 20:12:00+06\\")","(9,\\"2024-01-30 20:15:00+06\\")","(10,\\"2024-01-30 20:18:00+06\\")","(11,\\"2024-01-30 20:21:00+06\\")","(70,\\"2024-01-30 20:24:00+06\\")"}	from_buet	Ba-93-6087	t	abdulkarim6	\N	f	zahir53
1944	2024-01-30 23:30:00+06	1	evening	{"(1,\\"2024-01-30 23:30:00+06\\")","(2,\\"2024-01-30 23:37:00+06\\")","(3,\\"2024-01-30 23:40:00+06\\")","(4,\\"2024-01-30 23:42:00+06\\")","(5,\\"2024-01-30 23:44:00+06\\")","(6,\\"2024-01-30 23:56:00+06\\")","(7,\\"2024-01-30 23:59:00+06\\")","(8,\\"2024-01-30 00:02:00+06\\")","(9,\\"2024-01-30 00:05:00+06\\")","(10,\\"2024-01-30 00:08:00+06\\")","(11,\\"2024-01-30 00:11:00+06\\")","(70,\\"2024-01-30 00:14:00+06\\")"}	from_buet	Ba-93-6087	t	abdulkarim6	\N	f	zahir53
1945	2024-01-30 12:10:00+06	8	morning	{"(64,\\"2024-01-30 12:10:00+06\\")","(65,\\"2024-01-30 12:13:00+06\\")","(66,\\"2024-01-30 12:18:00+06\\")","(67,\\"2024-01-30 12:20:00+06\\")","(68,\\"2024-01-30 12:22:00+06\\")","(69,\\"2024-01-30 12:25:00+06\\")","(70,\\"2024-01-30 12:40:00+06\\")"}	to_buet	Ba-34-7413	t	shafiqul	\N	f	azim990
1946	2024-01-30 19:40:00+06	8	afternoon	{"(64,\\"2024-01-30 19:40:00+06\\")","(65,\\"2024-01-30 19:55:00+06\\")","(66,\\"2024-01-30 19:58:00+06\\")","(67,\\"2024-01-30 20:01:00+06\\")","(68,\\"2024-01-30 20:04:00+06\\")","(69,\\"2024-01-30 20:07:00+06\\")","(70,\\"2024-01-30 20:10:00+06\\")"}	from_buet	Ba-34-7413	t	shafiqul	\N	f	azim990
1947	2024-01-30 23:30:00+06	8	evening	{"(64,\\"2024-01-30 23:30:00+06\\")","(65,\\"2024-01-30 23:45:00+06\\")","(66,\\"2024-01-30 23:48:00+06\\")","(67,\\"2024-01-30 23:51:00+06\\")","(68,\\"2024-01-30 23:54:00+06\\")","(69,\\"2024-01-30 23:57:00+06\\")","(70,\\"2024-01-30 00:00:00+06\\")"}	from_buet	Ba-34-7413	t	shafiqul	\N	f	azim990
1948	2024-02-01 12:55:00+06	2	morning	{"(12,\\"2024-02-01 12:55:00+06\\")","(13,\\"2024-02-01 12:57:00+06\\")","(14,\\"2024-02-01 12:59:00+06\\")","(15,\\"2024-02-01 13:01:00+06\\")","(16,\\"2024-02-01 13:03:00+06\\")","(70,\\"2024-02-01 13:15:00+06\\")"}	to_buet	Ba-43-4286	t	monu67	nazmul	f	mahbub777
1949	2024-02-01 19:40:00+06	2	afternoon	{"(12,\\"2024-02-01 19:40:00+06\\")","(13,\\"2024-02-01 19:52:00+06\\")","(14,\\"2024-02-01 19:54:00+06\\")","(15,\\"2024-02-01 19:57:00+06\\")","(16,\\"2024-02-01 20:00:00+06\\")","(70,\\"2024-02-01 20:03:00+06\\")"}	from_buet	Ba-43-4286	t	monu67	nazmul	f	mahbub777
1950	2024-02-01 23:30:00+06	2	evening	{"(12,\\"2024-02-01 23:30:00+06\\")","(13,\\"2024-02-01 23:42:00+06\\")","(14,\\"2024-02-01 23:45:00+06\\")","(15,\\"2024-02-01 23:48:00+06\\")","(16,\\"2024-02-01 23:51:00+06\\")","(70,\\"2024-02-01 23:54:00+06\\")"}	from_buet	Ba-43-4286	t	monu67	nazmul	f	mahbub777
1951	2024-02-01 12:40:00+06	3	morning	{"(17,\\"2024-02-01 12:40:00+06\\")","(18,\\"2024-02-01 12:42:00+06\\")","(19,\\"2024-02-01 12:44:00+06\\")","(20,\\"2024-02-01 12:46:00+06\\")","(21,\\"2024-02-01 12:48:00+06\\")","(22,\\"2024-02-01 12:50:00+06\\")","(23,\\"2024-02-01 12:52:00+06\\")","(24,\\"2024-02-01 12:54:00+06\\")","(25,\\"2024-02-01 12:57:00+06\\")","(26,\\"2024-02-01 13:00:00+06\\")","(70,\\"2024-02-01 13:15:00+06\\")"}	to_buet	Ba-24-8518	t	sohel55	nazmul	f	alamgir
1952	2024-02-01 19:40:00+06	3	afternoon	{"(17,\\"2024-02-01 19:40:00+06\\")","(18,\\"2024-02-01 19:55:00+06\\")","(19,\\"2024-02-01 19:58:00+06\\")","(20,\\"2024-02-01 20:00:00+06\\")","(21,\\"2024-02-01 20:02:00+06\\")","(22,\\"2024-02-01 20:04:00+06\\")","(23,\\"2024-02-01 20:06:00+06\\")","(24,\\"2024-02-01 20:08:00+06\\")","(25,\\"2024-02-01 20:10:00+06\\")","(26,\\"2024-02-01 20:12:00+06\\")","(70,\\"2024-02-01 20:14:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	f	alamgir
1953	2024-02-01 23:30:00+06	3	evening	{"(17,\\"2024-02-01 23:30:00+06\\")","(18,\\"2024-02-01 23:45:00+06\\")","(19,\\"2024-02-01 23:48:00+06\\")","(20,\\"2024-02-01 23:50:00+06\\")","(21,\\"2024-02-01 23:52:00+06\\")","(22,\\"2024-02-01 23:54:00+06\\")","(23,\\"2024-02-01 23:56:00+06\\")","(24,\\"2024-02-01 23:58:00+06\\")","(25,\\"2024-02-01 00:00:00+06\\")","(26,\\"2024-02-01 00:02:00+06\\")","(70,\\"2024-02-01 00:04:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	f	alamgir
1954	2024-02-01 12:40:00+06	4	morning	{"(27,\\"2024-02-01 12:40:00+06\\")","(28,\\"2024-02-01 12:42:00+06\\")","(29,\\"2024-02-01 12:44:00+06\\")","(30,\\"2024-02-01 12:46:00+06\\")","(31,\\"2024-02-01 12:50:00+06\\")","(32,\\"2024-02-01 12:52:00+06\\")","(33,\\"2024-02-01 12:54:00+06\\")","(34,\\"2024-02-01 12:58:00+06\\")","(35,\\"2024-02-01 13:00:00+06\\")","(70,\\"2024-02-01 13:10:00+06\\")"}	to_buet	Ba-35-1461	t	altaf78	nazmul	f	mahabhu
1972	2024-02-05 12:55:00+06	2	morning	{"(12,\\"2024-02-05 12:55:00+06\\")","(13,\\"2024-02-05 12:57:00+06\\")","(14,\\"2024-02-05 12:59:00+06\\")","(15,\\"2024-02-05 13:01:00+06\\")","(16,\\"2024-02-05 13:03:00+06\\")","(70,\\"2024-02-05 13:15:00+06\\")"}	to_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81
1973	2024-02-05 19:40:00+06	2	afternoon	{"(12,\\"2024-02-05 19:40:00+06\\")","(13,\\"2024-02-05 19:52:00+06\\")","(14,\\"2024-02-05 19:54:00+06\\")","(15,\\"2024-02-05 19:57:00+06\\")","(16,\\"2024-02-05 20:00:00+06\\")","(70,\\"2024-02-05 20:03:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81
1974	2024-02-05 23:30:00+06	2	evening	{"(12,\\"2024-02-05 23:30:00+06\\")","(13,\\"2024-02-05 23:42:00+06\\")","(14,\\"2024-02-05 23:45:00+06\\")","(15,\\"2024-02-05 23:48:00+06\\")","(16,\\"2024-02-05 23:51:00+06\\")","(70,\\"2024-02-05 23:54:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81
1975	2024-02-05 12:40:00+06	3	morning	{"(17,\\"2024-02-05 12:40:00+06\\")","(18,\\"2024-02-05 12:42:00+06\\")","(19,\\"2024-02-05 12:44:00+06\\")","(20,\\"2024-02-05 12:46:00+06\\")","(21,\\"2024-02-05 12:48:00+06\\")","(22,\\"2024-02-05 12:50:00+06\\")","(23,\\"2024-02-05 12:52:00+06\\")","(24,\\"2024-02-05 12:54:00+06\\")","(25,\\"2024-02-05 12:57:00+06\\")","(26,\\"2024-02-05 13:00:00+06\\")","(70,\\"2024-02-05 13:15:00+06\\")"}	to_buet	Ba-69-8288	t	jahangir	nazmul	f	ASADUZZAMAN
1955	2024-02-01 19:40:00+06	4	afternoon	{"(27,\\"2024-02-01 19:40:00+06\\")","(28,\\"2024-02-01 19:50:00+06\\")","(29,\\"2024-02-01 19:52:00+06\\")","(30,\\"2024-02-01 19:54:00+06\\")","(31,\\"2024-02-01 19:56:00+06\\")","(32,\\"2024-02-01 19:58:00+06\\")","(33,\\"2024-02-01 20:00:00+06\\")","(34,\\"2024-02-01 20:02:00+06\\")","(35,\\"2024-02-01 20:04:00+06\\")","(70,\\"2024-02-01 20:06:00+06\\")"}	from_buet	Ba-35-1461	t	altaf78	nazmul	f	mahabhu
1956	2024-02-01 23:30:00+06	4	evening	{"(27,\\"2024-02-01 23:30:00+06\\")","(28,\\"2024-02-01 23:40:00+06\\")","(29,\\"2024-02-01 23:42:00+06\\")","(30,\\"2024-02-01 23:44:00+06\\")","(31,\\"2024-02-01 23:46:00+06\\")","(32,\\"2024-02-01 23:48:00+06\\")","(33,\\"2024-02-01 23:50:00+06\\")","(34,\\"2024-02-01 23:52:00+06\\")","(35,\\"2024-02-01 23:54:00+06\\")","(70,\\"2024-02-01 23:56:00+06\\")"}	from_buet	Ba-35-1461	t	altaf78	nazmul	f	mahabhu
1960	2024-02-01 12:40:00+06	6	morning	{"(41,\\"2024-02-01 12:40:00+06\\")","(42,\\"2024-02-01 12:42:00+06\\")","(43,\\"2024-02-01 12:45:00+06\\")","(44,\\"2024-02-01 12:47:00+06\\")","(45,\\"2024-02-01 12:49:00+06\\")","(46,\\"2024-02-01 12:51:00+06\\")","(47,\\"2024-02-01 12:52:00+06\\")","(48,\\"2024-02-01 12:53:00+06\\")","(49,\\"2024-02-01 12:54:00+06\\")","(70,\\"2024-02-01 13:10:00+06\\")"}	to_buet	Ba-63-1146	t	polash	nazmul	f	nasir81
1961	2024-02-01 19:40:00+06	6	afternoon	{"(41,\\"2024-02-01 19:40:00+06\\")","(42,\\"2024-02-01 19:56:00+06\\")","(43,\\"2024-02-01 19:58:00+06\\")","(44,\\"2024-02-01 20:00:00+06\\")","(45,\\"2024-02-01 20:02:00+06\\")","(46,\\"2024-02-01 20:04:00+06\\")","(47,\\"2024-02-01 20:06:00+06\\")","(48,\\"2024-02-01 20:08:00+06\\")","(49,\\"2024-02-01 20:10:00+06\\")","(70,\\"2024-02-01 20:12:00+06\\")"}	from_buet	Ba-63-1146	t	polash	nazmul	f	nasir81
1962	2024-02-01 23:30:00+06	6	evening	{"(41,\\"2024-02-01 23:30:00+06\\")","(42,\\"2024-02-01 23:46:00+06\\")","(43,\\"2024-02-01 23:48:00+06\\")","(44,\\"2024-02-01 23:50:00+06\\")","(45,\\"2024-02-01 23:52:00+06\\")","(46,\\"2024-02-01 23:54:00+06\\")","(47,\\"2024-02-01 23:56:00+06\\")","(48,\\"2024-02-01 23:58:00+06\\")","(49,\\"2024-02-01 00:00:00+06\\")","(70,\\"2024-02-01 00:02:00+06\\")"}	from_buet	Ba-63-1146	t	polash	nazmul	f	nasir81
1963	2024-02-01 12:40:00+06	7	morning	{"(50,\\"2024-02-01 12:40:00+06\\")","(51,\\"2024-02-01 12:42:00+06\\")","(52,\\"2024-02-01 12:43:00+06\\")","(53,\\"2024-02-01 12:46:00+06\\")","(54,\\"2024-02-01 12:47:00+06\\")","(55,\\"2024-02-01 12:48:00+06\\")","(56,\\"2024-02-01 12:50:00+06\\")","(57,\\"2024-02-01 12:52:00+06\\")","(58,\\"2024-02-01 12:53:00+06\\")","(59,\\"2024-02-01 12:54:00+06\\")","(60,\\"2024-02-01 12:56:00+06\\")","(61,\\"2024-02-01 12:58:00+06\\")","(62,\\"2024-02-01 13:00:00+06\\")","(63,\\"2024-02-01 13:02:00+06\\")","(70,\\"2024-02-01 13:00:00+06\\")"}	to_buet	Ba-83-8014	t	shahid88	nazmul	f	abdulbari4
1964	2024-02-01 19:40:00+06	7	afternoon	{"(50,\\"2024-02-01 19:40:00+06\\")","(51,\\"2024-02-01 19:48:00+06\\")","(52,\\"2024-02-01 19:50:00+06\\")","(53,\\"2024-02-01 19:52:00+06\\")","(54,\\"2024-02-01 19:54:00+06\\")","(55,\\"2024-02-01 19:56:00+06\\")","(56,\\"2024-02-01 19:58:00+06\\")","(57,\\"2024-02-01 20:00:00+06\\")","(58,\\"2024-02-01 20:02:00+06\\")","(59,\\"2024-02-01 20:04:00+06\\")","(60,\\"2024-02-01 20:06:00+06\\")","(61,\\"2024-02-01 20:08:00+06\\")","(62,\\"2024-02-01 20:10:00+06\\")","(63,\\"2024-02-01 20:12:00+06\\")","(70,\\"2024-02-01 20:14:00+06\\")"}	from_buet	Ba-83-8014	t	shahid88	nazmul	f	abdulbari4
1965	2024-02-01 23:30:00+06	7	evening	{"(50,\\"2024-02-01 23:30:00+06\\")","(51,\\"2024-02-01 23:38:00+06\\")","(52,\\"2024-02-01 23:40:00+06\\")","(53,\\"2024-02-01 23:42:00+06\\")","(54,\\"2024-02-01 23:44:00+06\\")","(55,\\"2024-02-01 23:46:00+06\\")","(56,\\"2024-02-01 23:48:00+06\\")","(57,\\"2024-02-01 23:50:00+06\\")","(58,\\"2024-02-01 23:52:00+06\\")","(59,\\"2024-02-01 23:54:00+06\\")","(60,\\"2024-02-01 23:56:00+06\\")","(61,\\"2024-02-01 23:58:00+06\\")","(62,\\"2024-02-01 00:00:00+06\\")","(63,\\"2024-02-01 00:02:00+06\\")","(70,\\"2024-02-01 00:04:00+06\\")"}	from_buet	Ba-83-8014	t	shahid88	nazmul	f	abdulbari4
1966	2024-02-01 12:15:00+06	1	morning	{"(1,\\"2024-02-01 12:15:00+06\\")","(2,\\"2024-02-01 12:18:00+06\\")","(3,\\"2024-02-01 12:20:00+06\\")","(4,\\"2024-02-01 12:23:00+06\\")","(5,\\"2024-02-01 12:26:00+06\\")","(6,\\"2024-02-01 12:29:00+06\\")","(7,\\"2024-02-01 12:49:00+06\\")","(8,\\"2024-02-01 12:51:00+06\\")","(9,\\"2024-02-01 12:53:00+06\\")","(10,\\"2024-02-01 12:55:00+06\\")","(11,\\"2024-02-01 12:58:00+06\\")","(70,\\"2024-02-01 13:05:00+06\\")"}	to_buet	Ba-98-5568	t	jahangir	nazmul	f	ASADUZZAMAN
1967	2024-02-01 19:40:00+06	1	afternoon	{"(1,\\"2024-02-01 19:40:00+06\\")","(2,\\"2024-02-01 19:47:00+06\\")","(3,\\"2024-02-01 19:50:00+06\\")","(4,\\"2024-02-01 19:52:00+06\\")","(5,\\"2024-02-01 19:54:00+06\\")","(6,\\"2024-02-01 20:06:00+06\\")","(7,\\"2024-02-01 20:09:00+06\\")","(8,\\"2024-02-01 20:12:00+06\\")","(9,\\"2024-02-01 20:15:00+06\\")","(10,\\"2024-02-01 20:18:00+06\\")","(11,\\"2024-02-01 20:21:00+06\\")","(70,\\"2024-02-01 20:24:00+06\\")"}	from_buet	Ba-98-5568	t	jahangir	nazmul	f	ASADUZZAMAN
1968	2024-02-01 23:30:00+06	1	evening	{"(1,\\"2024-02-01 23:30:00+06\\")","(2,\\"2024-02-01 23:37:00+06\\")","(3,\\"2024-02-01 23:40:00+06\\")","(4,\\"2024-02-01 23:42:00+06\\")","(5,\\"2024-02-01 23:44:00+06\\")","(6,\\"2024-02-01 23:56:00+06\\")","(7,\\"2024-02-01 23:59:00+06\\")","(8,\\"2024-02-01 00:02:00+06\\")","(9,\\"2024-02-01 00:05:00+06\\")","(10,\\"2024-02-01 00:08:00+06\\")","(11,\\"2024-02-01 00:11:00+06\\")","(70,\\"2024-02-01 00:14:00+06\\")"}	from_buet	Ba-98-5568	t	jahangir	nazmul	f	ASADUZZAMAN
1969	2024-02-01 12:10:00+06	8	morning	{"(64,\\"2024-02-01 12:10:00+06\\")","(65,\\"2024-02-01 12:13:00+06\\")","(66,\\"2024-02-01 12:18:00+06\\")","(67,\\"2024-02-01 12:20:00+06\\")","(68,\\"2024-02-01 12:22:00+06\\")","(69,\\"2024-02-01 12:25:00+06\\")","(70,\\"2024-02-01 12:40:00+06\\")"}	to_buet	Ba-36-1921	t	nizam88	nazmul	f	azim990
1976	2024-02-05 19:40:00+06	3	afternoon	{"(17,\\"2024-02-05 19:40:00+06\\")","(18,\\"2024-02-05 19:55:00+06\\")","(19,\\"2024-02-05 19:58:00+06\\")","(20,\\"2024-02-05 20:00:00+06\\")","(21,\\"2024-02-05 20:02:00+06\\")","(22,\\"2024-02-05 20:04:00+06\\")","(23,\\"2024-02-05 20:06:00+06\\")","(24,\\"2024-02-05 20:08:00+06\\")","(25,\\"2024-02-05 20:10:00+06\\")","(26,\\"2024-02-05 20:12:00+06\\")","(70,\\"2024-02-05 20:14:00+06\\")"}	from_buet	Ba-69-8288	t	jahangir	nazmul	f	ASADUZZAMAN
1977	2024-02-05 23:30:00+06	3	evening	{"(17,\\"2024-02-05 23:30:00+06\\")","(18,\\"2024-02-05 23:45:00+06\\")","(19,\\"2024-02-05 23:48:00+06\\")","(20,\\"2024-02-05 23:50:00+06\\")","(21,\\"2024-02-05 23:52:00+06\\")","(22,\\"2024-02-05 23:54:00+06\\")","(23,\\"2024-02-05 23:56:00+06\\")","(24,\\"2024-02-05 23:58:00+06\\")","(25,\\"2024-02-05 00:00:00+06\\")","(26,\\"2024-02-05 00:02:00+06\\")","(70,\\"2024-02-05 00:04:00+06\\")"}	from_buet	Ba-69-8288	t	jahangir	nazmul	f	ASADUZZAMAN
1978	2024-02-05 12:40:00+06	4	morning	{"(27,\\"2024-02-05 12:40:00+06\\")","(28,\\"2024-02-05 12:42:00+06\\")","(29,\\"2024-02-05 12:44:00+06\\")","(30,\\"2024-02-05 12:46:00+06\\")","(31,\\"2024-02-05 12:50:00+06\\")","(32,\\"2024-02-05 12:52:00+06\\")","(33,\\"2024-02-05 12:54:00+06\\")","(34,\\"2024-02-05 12:58:00+06\\")","(35,\\"2024-02-05 13:00:00+06\\")","(70,\\"2024-02-05 13:10:00+06\\")"}	to_buet	Ba-93-6087	t	rahmatullah	nazmul	f	shamsul54
1979	2024-02-05 19:40:00+06	4	afternoon	{"(27,\\"2024-02-05 19:40:00+06\\")","(28,\\"2024-02-05 19:50:00+06\\")","(29,\\"2024-02-05 19:52:00+06\\")","(30,\\"2024-02-05 19:54:00+06\\")","(31,\\"2024-02-05 19:56:00+06\\")","(32,\\"2024-02-05 19:58:00+06\\")","(33,\\"2024-02-05 20:00:00+06\\")","(34,\\"2024-02-05 20:02:00+06\\")","(35,\\"2024-02-05 20:04:00+06\\")","(70,\\"2024-02-05 20:06:00+06\\")"}	from_buet	Ba-93-6087	t	rahmatullah	nazmul	f	shamsul54
1980	2024-02-05 23:30:00+06	4	evening	{"(27,\\"2024-02-05 23:30:00+06\\")","(28,\\"2024-02-05 23:40:00+06\\")","(29,\\"2024-02-05 23:42:00+06\\")","(30,\\"2024-02-05 23:44:00+06\\")","(31,\\"2024-02-05 23:46:00+06\\")","(32,\\"2024-02-05 23:48:00+06\\")","(33,\\"2024-02-05 23:50:00+06\\")","(34,\\"2024-02-05 23:52:00+06\\")","(35,\\"2024-02-05 23:54:00+06\\")","(70,\\"2024-02-05 23:56:00+06\\")"}	from_buet	Ba-93-6087	t	rahmatullah	nazmul	f	shamsul54
1981	2024-02-05 12:30:00+06	5	morning	{"(36,\\"2024-02-05 12:30:00+06\\")","(37,\\"2024-02-05 12:33:00+06\\")","(38,\\"2024-02-05 12:40:00+06\\")","(39,\\"2024-02-05 12:45:00+06\\")","(40,\\"2024-02-05 12:50:00+06\\")","(70,\\"2024-02-05 13:00:00+06\\")"}	to_buet	Ba-17-2081	t	shafiqul	nazmul	f	mahabhu
1982	2024-02-05 19:40:00+06	5	afternoon	{"(36,\\"2024-02-05 19:40:00+06\\")","(37,\\"2024-02-05 19:50:00+06\\")","(38,\\"2024-02-05 19:55:00+06\\")","(39,\\"2024-02-05 20:00:00+06\\")","(40,\\"2024-02-05 20:07:00+06\\")","(70,\\"2024-02-05 20:10:00+06\\")"}	from_buet	Ba-17-2081	t	shafiqul	nazmul	f	mahabhu
1983	2024-02-05 23:30:00+06	5	evening	{"(36,\\"2024-02-05 23:30:00+06\\")","(37,\\"2024-02-05 23:40:00+06\\")","(38,\\"2024-02-05 23:45:00+06\\")","(39,\\"2024-02-05 23:50:00+06\\")","(40,\\"2024-02-05 23:57:00+06\\")","(70,\\"2024-02-05 00:00:00+06\\")"}	from_buet	Ba-17-2081	t	shafiqul	nazmul	f	mahabhu
1984	2024-02-05 12:40:00+06	6	morning	{"(41,\\"2024-02-05 12:40:00+06\\")","(42,\\"2024-02-05 12:42:00+06\\")","(43,\\"2024-02-05 12:45:00+06\\")","(44,\\"2024-02-05 12:47:00+06\\")","(45,\\"2024-02-05 12:49:00+06\\")","(46,\\"2024-02-05 12:51:00+06\\")","(47,\\"2024-02-05 12:52:00+06\\")","(48,\\"2024-02-05 12:53:00+06\\")","(49,\\"2024-02-05 12:54:00+06\\")","(70,\\"2024-02-05 13:10:00+06\\")"}	to_buet	Ba-12-8888	t	aminhaque	nazmul	f	alamgir
1985	2024-02-05 19:40:00+06	6	afternoon	{"(41,\\"2024-02-05 19:40:00+06\\")","(42,\\"2024-02-05 19:56:00+06\\")","(43,\\"2024-02-05 19:58:00+06\\")","(44,\\"2024-02-05 20:00:00+06\\")","(45,\\"2024-02-05 20:02:00+06\\")","(46,\\"2024-02-05 20:04:00+06\\")","(47,\\"2024-02-05 20:06:00+06\\")","(48,\\"2024-02-05 20:08:00+06\\")","(49,\\"2024-02-05 20:10:00+06\\")","(70,\\"2024-02-05 20:12:00+06\\")"}	from_buet	Ba-12-8888	t	aminhaque	nazmul	f	alamgir
1986	2024-02-05 23:30:00+06	6	evening	{"(41,\\"2024-02-05 23:30:00+06\\")","(42,\\"2024-02-05 23:46:00+06\\")","(43,\\"2024-02-05 23:48:00+06\\")","(44,\\"2024-02-05 23:50:00+06\\")","(45,\\"2024-02-05 23:52:00+06\\")","(46,\\"2024-02-05 23:54:00+06\\")","(47,\\"2024-02-05 23:56:00+06\\")","(48,\\"2024-02-05 23:58:00+06\\")","(49,\\"2024-02-05 00:00:00+06\\")","(70,\\"2024-02-05 00:02:00+06\\")"}	from_buet	Ba-12-8888	t	aminhaque	nazmul	f	alamgir
1987	2024-02-05 12:40:00+06	7	morning	{"(50,\\"2024-02-05 12:40:00+06\\")","(51,\\"2024-02-05 12:42:00+06\\")","(52,\\"2024-02-05 12:43:00+06\\")","(53,\\"2024-02-05 12:46:00+06\\")","(54,\\"2024-02-05 12:47:00+06\\")","(55,\\"2024-02-05 12:48:00+06\\")","(56,\\"2024-02-05 12:50:00+06\\")","(57,\\"2024-02-05 12:52:00+06\\")","(58,\\"2024-02-05 12:53:00+06\\")","(59,\\"2024-02-05 12:54:00+06\\")","(60,\\"2024-02-05 12:56:00+06\\")","(61,\\"2024-02-05 12:58:00+06\\")","(62,\\"2024-02-05 13:00:00+06\\")","(63,\\"2024-02-05 13:02:00+06\\")","(70,\\"2024-02-05 13:00:00+06\\")"}	to_buet	Ba-98-5568	t	polash	nazmul	f	mahmud64
1988	2024-02-05 19:40:00+06	7	afternoon	{"(50,\\"2024-02-05 19:40:00+06\\")","(51,\\"2024-02-05 19:48:00+06\\")","(52,\\"2024-02-05 19:50:00+06\\")","(53,\\"2024-02-05 19:52:00+06\\")","(54,\\"2024-02-05 19:54:00+06\\")","(55,\\"2024-02-05 19:56:00+06\\")","(56,\\"2024-02-05 19:58:00+06\\")","(57,\\"2024-02-05 20:00:00+06\\")","(58,\\"2024-02-05 20:02:00+06\\")","(59,\\"2024-02-05 20:04:00+06\\")","(60,\\"2024-02-05 20:06:00+06\\")","(61,\\"2024-02-05 20:08:00+06\\")","(62,\\"2024-02-05 20:10:00+06\\")","(63,\\"2024-02-05 20:12:00+06\\")","(70,\\"2024-02-05 20:14:00+06\\")"}	from_buet	Ba-98-5568	t	polash	nazmul	f	mahmud64
1989	2024-02-05 23:30:00+06	7	evening	{"(50,\\"2024-02-05 23:30:00+06\\")","(51,\\"2024-02-05 23:38:00+06\\")","(52,\\"2024-02-05 23:40:00+06\\")","(53,\\"2024-02-05 23:42:00+06\\")","(54,\\"2024-02-05 23:44:00+06\\")","(55,\\"2024-02-05 23:46:00+06\\")","(56,\\"2024-02-05 23:48:00+06\\")","(57,\\"2024-02-05 23:50:00+06\\")","(58,\\"2024-02-05 23:52:00+06\\")","(59,\\"2024-02-05 23:54:00+06\\")","(60,\\"2024-02-05 23:56:00+06\\")","(61,\\"2024-02-05 23:58:00+06\\")","(62,\\"2024-02-05 00:00:00+06\\")","(63,\\"2024-02-05 00:02:00+06\\")","(70,\\"2024-02-05 00:04:00+06\\")"}	from_buet	Ba-98-5568	t	polash	nazmul	f	mahmud64
1993	2024-02-05 12:10:00+06	8	morning	{"(64,\\"2024-02-05 12:10:00+06\\")","(65,\\"2024-02-05 12:13:00+06\\")","(66,\\"2024-02-05 12:18:00+06\\")","(67,\\"2024-02-05 12:20:00+06\\")","(68,\\"2024-02-05 12:22:00+06\\")","(69,\\"2024-02-05 12:25:00+06\\")","(70,\\"2024-02-05 12:40:00+06\\")"}	to_buet	Ba-97-6734	t	monu67	nazmul	f	farid99
1994	2024-02-05 19:40:00+06	8	afternoon	{"(64,\\"2024-02-05 19:40:00+06\\")","(65,\\"2024-02-05 19:55:00+06\\")","(66,\\"2024-02-05 19:58:00+06\\")","(67,\\"2024-02-05 20:01:00+06\\")","(68,\\"2024-02-05 20:04:00+06\\")","(69,\\"2024-02-05 20:07:00+06\\")","(70,\\"2024-02-05 20:10:00+06\\")"}	from_buet	Ba-97-6734	t	monu67	nazmul	f	farid99
1995	2024-02-05 23:30:00+06	8	evening	{"(64,\\"2024-02-05 23:30:00+06\\")","(65,\\"2024-02-05 23:45:00+06\\")","(66,\\"2024-02-05 23:48:00+06\\")","(67,\\"2024-02-05 23:51:00+06\\")","(68,\\"2024-02-05 23:54:00+06\\")","(69,\\"2024-02-05 23:57:00+06\\")","(70,\\"2024-02-05 00:00:00+06\\")"}	from_buet	Ba-97-6734	t	monu67	nazmul	f	farid99
1996	2024-02-01 12:55:00+06	2	morning	{"(12,\\"2024-02-01 12:55:00+06\\")","(13,\\"2024-02-01 12:57:00+06\\")","(14,\\"2024-02-01 12:59:00+06\\")","(15,\\"2024-02-01 13:01:00+06\\")","(16,\\"2024-02-01 13:03:00+06\\")","(70,\\"2024-02-01 13:15:00+06\\")"}	to_buet	Ba-48-5757	t	arif43	\N	f	mahbub777
1997	2024-02-01 19:40:00+06	2	afternoon	{"(12,\\"2024-02-01 19:40:00+06\\")","(13,\\"2024-02-01 19:52:00+06\\")","(14,\\"2024-02-01 19:54:00+06\\")","(15,\\"2024-02-01 19:57:00+06\\")","(16,\\"2024-02-01 20:00:00+06\\")","(70,\\"2024-02-01 20:03:00+06\\")"}	from_buet	Ba-48-5757	t	arif43	\N	f	mahbub777
1998	2024-02-01 23:30:00+06	2	evening	{"(12,\\"2024-02-01 23:30:00+06\\")","(13,\\"2024-02-01 23:42:00+06\\")","(14,\\"2024-02-01 23:45:00+06\\")","(15,\\"2024-02-01 23:48:00+06\\")","(16,\\"2024-02-01 23:51:00+06\\")","(70,\\"2024-02-01 23:54:00+06\\")"}	from_buet	Ba-48-5757	t	arif43	\N	f	mahbub777
1999	2024-02-01 12:40:00+06	3	morning	{"(17,\\"2024-02-01 12:40:00+06\\")","(18,\\"2024-02-01 12:42:00+06\\")","(19,\\"2024-02-01 12:44:00+06\\")","(20,\\"2024-02-01 12:46:00+06\\")","(21,\\"2024-02-01 12:48:00+06\\")","(22,\\"2024-02-01 12:50:00+06\\")","(23,\\"2024-02-01 12:52:00+06\\")","(24,\\"2024-02-01 12:54:00+06\\")","(25,\\"2024-02-01 12:57:00+06\\")","(26,\\"2024-02-01 13:00:00+06\\")","(70,\\"2024-02-01 13:15:00+06\\")"}	to_buet	Ba-34-7413	t	nizam88	\N	f	farid99
2000	2024-02-01 19:40:00+06	3	afternoon	{"(17,\\"2024-02-01 19:40:00+06\\")","(18,\\"2024-02-01 19:55:00+06\\")","(19,\\"2024-02-01 19:58:00+06\\")","(20,\\"2024-02-01 20:00:00+06\\")","(21,\\"2024-02-01 20:02:00+06\\")","(22,\\"2024-02-01 20:04:00+06\\")","(23,\\"2024-02-01 20:06:00+06\\")","(24,\\"2024-02-01 20:08:00+06\\")","(25,\\"2024-02-01 20:10:00+06\\")","(26,\\"2024-02-01 20:12:00+06\\")","(70,\\"2024-02-01 20:14:00+06\\")"}	from_buet	Ba-34-7413	t	nizam88	\N	f	farid99
2001	2024-02-01 23:30:00+06	3	evening	{"(17,\\"2024-02-01 23:30:00+06\\")","(18,\\"2024-02-01 23:45:00+06\\")","(19,\\"2024-02-01 23:48:00+06\\")","(20,\\"2024-02-01 23:50:00+06\\")","(21,\\"2024-02-01 23:52:00+06\\")","(22,\\"2024-02-01 23:54:00+06\\")","(23,\\"2024-02-01 23:56:00+06\\")","(24,\\"2024-02-01 23:58:00+06\\")","(25,\\"2024-02-01 00:00:00+06\\")","(26,\\"2024-02-01 00:02:00+06\\")","(70,\\"2024-02-01 00:04:00+06\\")"}	from_buet	Ba-34-7413	t	nizam88	\N	f	farid99
2002	2024-02-01 12:40:00+06	4	morning	{"(27,\\"2024-02-01 12:40:00+06\\")","(28,\\"2024-02-01 12:42:00+06\\")","(29,\\"2024-02-01 12:44:00+06\\")","(30,\\"2024-02-01 12:46:00+06\\")","(31,\\"2024-02-01 12:50:00+06\\")","(32,\\"2024-02-01 12:52:00+06\\")","(33,\\"2024-02-01 12:54:00+06\\")","(34,\\"2024-02-01 12:58:00+06\\")","(35,\\"2024-02-01 13:00:00+06\\")","(70,\\"2024-02-01 13:10:00+06\\")"}	to_buet	Ba-20-3066	t	nazrul6	\N	f	mahmud64
2003	2024-02-01 19:40:00+06	4	afternoon	{"(27,\\"2024-02-01 19:40:00+06\\")","(28,\\"2024-02-01 19:50:00+06\\")","(29,\\"2024-02-01 19:52:00+06\\")","(30,\\"2024-02-01 19:54:00+06\\")","(31,\\"2024-02-01 19:56:00+06\\")","(32,\\"2024-02-01 19:58:00+06\\")","(33,\\"2024-02-01 20:00:00+06\\")","(34,\\"2024-02-01 20:02:00+06\\")","(35,\\"2024-02-01 20:04:00+06\\")","(70,\\"2024-02-01 20:06:00+06\\")"}	from_buet	Ba-20-3066	t	nazrul6	\N	f	mahmud64
2004	2024-02-01 23:30:00+06	4	evening	{"(27,\\"2024-02-01 23:30:00+06\\")","(28,\\"2024-02-01 23:40:00+06\\")","(29,\\"2024-02-01 23:42:00+06\\")","(30,\\"2024-02-01 23:44:00+06\\")","(31,\\"2024-02-01 23:46:00+06\\")","(32,\\"2024-02-01 23:48:00+06\\")","(33,\\"2024-02-01 23:50:00+06\\")","(34,\\"2024-02-01 23:52:00+06\\")","(35,\\"2024-02-01 23:54:00+06\\")","(70,\\"2024-02-01 23:56:00+06\\")"}	from_buet	Ba-20-3066	t	nazrul6	\N	f	mahmud64
2005	2024-02-01 12:30:00+06	5	morning	{"(36,\\"2024-02-01 12:30:00+06\\")","(37,\\"2024-02-01 12:33:00+06\\")","(38,\\"2024-02-01 12:40:00+06\\")","(39,\\"2024-02-01 12:45:00+06\\")","(40,\\"2024-02-01 12:50:00+06\\")","(70,\\"2024-02-01 13:00:00+06\\")"}	to_buet	Ba-17-3886	t	aminhaque	\N	f	siddiq2
2006	2024-02-01 19:40:00+06	5	afternoon	{"(36,\\"2024-02-01 19:40:00+06\\")","(37,\\"2024-02-01 19:50:00+06\\")","(38,\\"2024-02-01 19:55:00+06\\")","(39,\\"2024-02-01 20:00:00+06\\")","(40,\\"2024-02-01 20:07:00+06\\")","(70,\\"2024-02-01 20:10:00+06\\")"}	from_buet	Ba-17-3886	t	aminhaque	\N	f	siddiq2
2007	2024-02-01 23:30:00+06	5	evening	{"(36,\\"2024-02-01 23:30:00+06\\")","(37,\\"2024-02-01 23:40:00+06\\")","(38,\\"2024-02-01 23:45:00+06\\")","(39,\\"2024-02-01 23:50:00+06\\")","(40,\\"2024-02-01 23:57:00+06\\")","(70,\\"2024-02-01 00:00:00+06\\")"}	from_buet	Ba-17-3886	t	aminhaque	\N	f	siddiq2
2008	2024-02-01 12:40:00+06	6	morning	{"(41,\\"2024-02-01 12:40:00+06\\")","(42,\\"2024-02-01 12:42:00+06\\")","(43,\\"2024-02-01 12:45:00+06\\")","(44,\\"2024-02-01 12:47:00+06\\")","(45,\\"2024-02-01 12:49:00+06\\")","(46,\\"2024-02-01 12:51:00+06\\")","(47,\\"2024-02-01 12:52:00+06\\")","(48,\\"2024-02-01 12:53:00+06\\")","(49,\\"2024-02-01 12:54:00+06\\")","(70,\\"2024-02-01 13:10:00+06\\")"}	to_buet	Ba-35-1461	t	rafiqul	\N	f	alamgir
2009	2024-02-01 19:40:00+06	6	afternoon	{"(41,\\"2024-02-01 19:40:00+06\\")","(42,\\"2024-02-01 19:56:00+06\\")","(43,\\"2024-02-01 19:58:00+06\\")","(44,\\"2024-02-01 20:00:00+06\\")","(45,\\"2024-02-01 20:02:00+06\\")","(46,\\"2024-02-01 20:04:00+06\\")","(47,\\"2024-02-01 20:06:00+06\\")","(48,\\"2024-02-01 20:08:00+06\\")","(49,\\"2024-02-01 20:10:00+06\\")","(70,\\"2024-02-01 20:12:00+06\\")"}	from_buet	Ba-35-1461	t	rafiqul	\N	f	alamgir
2010	2024-02-01 23:30:00+06	6	evening	{"(41,\\"2024-02-01 23:30:00+06\\")","(42,\\"2024-02-01 23:46:00+06\\")","(43,\\"2024-02-01 23:48:00+06\\")","(44,\\"2024-02-01 23:50:00+06\\")","(45,\\"2024-02-01 23:52:00+06\\")","(46,\\"2024-02-01 23:54:00+06\\")","(47,\\"2024-02-01 23:56:00+06\\")","(48,\\"2024-02-01 23:58:00+06\\")","(49,\\"2024-02-01 00:00:00+06\\")","(70,\\"2024-02-01 00:02:00+06\\")"}	from_buet	Ba-35-1461	t	rafiqul	\N	f	alamgir
2011	2024-02-01 12:40:00+06	7	morning	{"(50,\\"2024-02-01 12:40:00+06\\")","(51,\\"2024-02-01 12:42:00+06\\")","(52,\\"2024-02-01 12:43:00+06\\")","(53,\\"2024-02-01 12:46:00+06\\")","(54,\\"2024-02-01 12:47:00+06\\")","(55,\\"2024-02-01 12:48:00+06\\")","(56,\\"2024-02-01 12:50:00+06\\")","(57,\\"2024-02-01 12:52:00+06\\")","(58,\\"2024-02-01 12:53:00+06\\")","(59,\\"2024-02-01 12:54:00+06\\")","(60,\\"2024-02-01 12:56:00+06\\")","(61,\\"2024-02-01 12:58:00+06\\")","(62,\\"2024-02-01 13:00:00+06\\")","(63,\\"2024-02-01 13:02:00+06\\")","(70,\\"2024-02-01 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	masud84	\N	f	shamsul54
2012	2024-02-01 19:40:00+06	7	afternoon	{"(50,\\"2024-02-01 19:40:00+06\\")","(51,\\"2024-02-01 19:48:00+06\\")","(52,\\"2024-02-01 19:50:00+06\\")","(53,\\"2024-02-01 19:52:00+06\\")","(54,\\"2024-02-01 19:54:00+06\\")","(55,\\"2024-02-01 19:56:00+06\\")","(56,\\"2024-02-01 19:58:00+06\\")","(57,\\"2024-02-01 20:00:00+06\\")","(58,\\"2024-02-01 20:02:00+06\\")","(59,\\"2024-02-01 20:04:00+06\\")","(60,\\"2024-02-01 20:06:00+06\\")","(61,\\"2024-02-01 20:08:00+06\\")","(62,\\"2024-02-01 20:10:00+06\\")","(63,\\"2024-02-01 20:12:00+06\\")","(70,\\"2024-02-01 20:14:00+06\\")"}	from_buet	Ba-24-8518	t	masud84	\N	f	shamsul54
2013	2024-02-01 23:30:00+06	7	evening	{"(50,\\"2024-02-01 23:30:00+06\\")","(51,\\"2024-02-01 23:38:00+06\\")","(52,\\"2024-02-01 23:40:00+06\\")","(53,\\"2024-02-01 23:42:00+06\\")","(54,\\"2024-02-01 23:44:00+06\\")","(55,\\"2024-02-01 23:46:00+06\\")","(56,\\"2024-02-01 23:48:00+06\\")","(57,\\"2024-02-01 23:50:00+06\\")","(58,\\"2024-02-01 23:52:00+06\\")","(59,\\"2024-02-01 23:54:00+06\\")","(60,\\"2024-02-01 23:56:00+06\\")","(61,\\"2024-02-01 23:58:00+06\\")","(62,\\"2024-02-01 00:00:00+06\\")","(63,\\"2024-02-01 00:02:00+06\\")","(70,\\"2024-02-01 00:04:00+06\\")"}	from_buet	Ba-24-8518	t	masud84	\N	f	shamsul54
2014	2024-02-01 12:15:00+06	1	morning	{"(1,\\"2024-02-01 12:15:00+06\\")","(2,\\"2024-02-01 12:18:00+06\\")","(3,\\"2024-02-01 12:20:00+06\\")","(4,\\"2024-02-01 12:23:00+06\\")","(5,\\"2024-02-01 12:26:00+06\\")","(6,\\"2024-02-01 12:29:00+06\\")","(7,\\"2024-02-01 12:49:00+06\\")","(8,\\"2024-02-01 12:51:00+06\\")","(9,\\"2024-02-01 12:53:00+06\\")","(10,\\"2024-02-01 12:55:00+06\\")","(11,\\"2024-02-01 12:58:00+06\\")","(70,\\"2024-02-01 13:05:00+06\\")"}	to_buet	Ba-22-4326	t	rahmatullah	\N	f	reyazul
2015	2024-02-01 19:40:00+06	1	afternoon	{"(1,\\"2024-02-01 19:40:00+06\\")","(2,\\"2024-02-01 19:47:00+06\\")","(3,\\"2024-02-01 19:50:00+06\\")","(4,\\"2024-02-01 19:52:00+06\\")","(5,\\"2024-02-01 19:54:00+06\\")","(6,\\"2024-02-01 20:06:00+06\\")","(7,\\"2024-02-01 20:09:00+06\\")","(8,\\"2024-02-01 20:12:00+06\\")","(9,\\"2024-02-01 20:15:00+06\\")","(10,\\"2024-02-01 20:18:00+06\\")","(11,\\"2024-02-01 20:21:00+06\\")","(70,\\"2024-02-01 20:24:00+06\\")"}	from_buet	Ba-22-4326	t	rahmatullah	\N	f	reyazul
2016	2024-02-01 23:30:00+06	1	evening	{"(1,\\"2024-02-01 23:30:00+06\\")","(2,\\"2024-02-01 23:37:00+06\\")","(3,\\"2024-02-01 23:40:00+06\\")","(4,\\"2024-02-01 23:42:00+06\\")","(5,\\"2024-02-01 23:44:00+06\\")","(6,\\"2024-02-01 23:56:00+06\\")","(7,\\"2024-02-01 23:59:00+06\\")","(8,\\"2024-02-01 00:02:00+06\\")","(9,\\"2024-02-01 00:05:00+06\\")","(10,\\"2024-02-01 00:08:00+06\\")","(11,\\"2024-02-01 00:11:00+06\\")","(70,\\"2024-02-01 00:14:00+06\\")"}	from_buet	Ba-22-4326	t	rahmatullah	\N	f	reyazul
2017	2024-02-01 12:10:00+06	8	morning	{"(64,\\"2024-02-01 12:10:00+06\\")","(65,\\"2024-02-01 12:13:00+06\\")","(66,\\"2024-02-01 12:18:00+06\\")","(67,\\"2024-02-01 12:20:00+06\\")","(68,\\"2024-02-01 12:22:00+06\\")","(69,\\"2024-02-01 12:25:00+06\\")","(70,\\"2024-02-01 12:40:00+06\\")"}	to_buet	Ba-85-4722	t	rashed3	\N	f	rashid56
2018	2024-02-01 19:40:00+06	8	afternoon	{"(64,\\"2024-02-01 19:40:00+06\\")","(65,\\"2024-02-01 19:55:00+06\\")","(66,\\"2024-02-01 19:58:00+06\\")","(67,\\"2024-02-01 20:01:00+06\\")","(68,\\"2024-02-01 20:04:00+06\\")","(69,\\"2024-02-01 20:07:00+06\\")","(70,\\"2024-02-01 20:10:00+06\\")"}	from_buet	Ba-85-4722	t	rashed3	\N	f	rashid56
2019	2024-02-01 23:30:00+06	8	evening	{"(64,\\"2024-02-01 23:30:00+06\\")","(65,\\"2024-02-01 23:45:00+06\\")","(66,\\"2024-02-01 23:48:00+06\\")","(67,\\"2024-02-01 23:51:00+06\\")","(68,\\"2024-02-01 23:54:00+06\\")","(69,\\"2024-02-01 23:57:00+06\\")","(70,\\"2024-02-01 00:00:00+06\\")"}	from_buet	Ba-85-4722	t	rashed3	\N	f	rashid56
\.


--
-- Data for Name: buet_staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buet_staff (id, name, department, designation, residence, password, phone) FROM stdin;
fahim	Sheikh Azizul Hakim	CSE	Lecturer	Demra	1705002	01234567890
jawad	Jawad Ul Alam	EEE	Lecturer	Nakhalpara	1706000	01234567890
mashiat	Mashiat Mustaq	CSE	Lecturer	Kallyanpur	1705005	01234567890
mrinmoy	Mrinmoy Kundu	EEE	Lecturer	Khilgaon	1706001	01234567890
rayhan	Rayhan Rashed	CSE	Lecturer	Mohammadpur	1505005	01234567890
sayem	Sayem Hasan	CSE	Lecturer	Basabo	1705027	01234567890
younus	Junayed Younus Khan	CSE	Professor	Teachers' Quarter	password	01234567890
pranto	Md. Toufikuzzaman	CSE	Lecturer	mirpur	1405015	01878117218
\.


--
-- Data for Name: buet_staff_feedback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buet_staff_feedback (id, complainer_id, route, submission_timestamp, concerned_timestamp, text, trip_id, subject, response) FROM stdin;
45	pranto	3	2024-01-24 07:59:49.727805+06	2024-01-23 00:00:00+06	nsns	\N	{bus}	\N
46	pranto	3	2024-01-24 11:38:25.472839+06	2024-01-25 00:00:00+06	hsjsj	\N	{driver}	\N
\.


--
-- Data for Name: bus; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bus (reg_id, type, capacity, remarks) FROM stdin;
Ba-98-5568	mini	30	\N
Ba-71-7930	mini	30	\N
Ba-85-4722	normal	60	\N
Ba-34-7413	mini	30	\N
Ba-24-8518	double_decker	100	\N
Ba-22-4326	mini	30	\N
Ba-83-8014	mini	30	\N
Ba-86-1841	normal	60	\N
Ba-20-3066	normal	60	\N
Ba-43-4286	mini	30	\N
Ba-17-3886	double_decker	100	\N
Ba-46-1334	mini	30	\N
Ba-63-1146	double_decker	100	\N
Ba-97-6734	mini	30	\N
Ba-17-2081	double_decker	100	\N
Ba-93-6087	mini	30	\N
Ba-36-1921	normal	60	\N
Ba-35-1461	normal	60	\N
Ba-48-5757	mini	30	\N
Ba-77-7044	mini	30	\N
Ba-69-8288	double_decker	60	\N
Ba-12-8888	mini	60	\N
Ba-19-0569	double_decker	69	\N
BA-01-2345	single_decker	30	Imported from Japan
\.


--
-- Data for Name: bus_staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bus_staff (id, phone, password, role, name) FROM stdin;
alamgir	01724276193	123	collector	Alamgir Hossain
sohel55	01913144741	xyz	driver	Sohel Mia
mahabhu	01646168292	password	collector	Code Forcesuz Zaman
arif43	01717596989	43arif	driver	Arif Hossain
azim990	01731184023	B07p3QRyu789	collector	Azim Ahmed
altaf78	01711840323	^#]U2&gqS;!%	driver	Altaf Mia
reyazul	01521564738	X!OR&`mW{UM_	collector	Kazi Rreyazul
altaf	01552459657	abcd1234	driver	Altaf Hossain
rahmatullah	01747457646	zxcvbnm,	driver	Hazi Rahmatullah
monu67	01345678902	12345678	driver	Monu Mia
ibrahim	01987654321	87654321	driver	Khondker Ibrahim
polash	01678923456	qwertyuiop	driver	Polash Sikder
rafiqul	01624582525	nfpdaaha	driver	Rafiqul Hasan
nizam88	01589742446	baiiknmc	driver	Nizamuddin Ahmed
kamaluddin	01764619110	ugllvyzg	driver	Kamal Uddin
shafiqul	01590909583	fynmspvn	driver	Shafiqul Islam
abdulkarim6	01653913218	qizsnccs	driver	Abdul Karim
imranhashmi	01826020989	botwlgnv	driver	Imran Khan
jahangir	01593143605	dkgyaxvh	driver	Jahangir Alam
rashed3	01410038120	mzzqreeq	driver	Rashedul Haque
nazrul6	01699974102	nlrqjmmn	driver	Nazrul Islam
masud84	01333694280	plizcayc	driver	Masudur Rahman
shahid88	01721202729	djhevuoy	driver	Shahid Khan
aminhaque	01623557727	aizumkcq	driver	Aminul Haque
fazlu77	01846939488	tphwfico	driver	Fazlur Rahman
mahmud64	01328226564	duuviutl	collector	Mahmudul Hasan
shamsul54	01595195413	oyewfxmf	collector	Shamsul Islam
abdulbari4	01317233333	vuvfxuml	collector	Abdul Bari
ASADUZZAMAN	01767495642	siewjpqc	collector	Asaduzzaman
farid99	01835421047	sdbzcgwq	collector	Farid Uddin
zahir53	01445850507	hbnkxwce	collector	Zahirul Islam
jamal7898	01308831356	ovdukfwq	collector	Jamal Uddin
rashid56	01719898746	ktgcfydp	collector	Rashidul Haque
sharif86r	01405293626	iswrmqsa	collector	Sharif Ahmed
mahbub777	01987835715	nqtgtodn	collector	Mahbubur Rahman
khairul	01732238594	sjjsgxtg	collector	Khairul Hasan
siddiq2	01451355422	eymsztoa	collector	Siddiqur Rahman
nasir81	01481194926	lkhkblym	collector	Nasir Uddin
\.


--
-- Data for Name: inventory; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventory (id, name, amount, rate) FROM stdin;
\.


--
-- Data for Name: purchase; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.purchase (id, buyer_id, "timestamp", payment_method, trxid, quantity) FROM stdin;
50	1905084	2024-01-24 16:35:20.337532+06	shurjopay	65b0e7e7	27
51	1905084	2024-01-24 16:38:19.039968+06	shurjopay	65b0e899	14
52	69	2024-01-24 17:39:29.853509+06	shurjopay	65b0f6f0	8
53	1905067	2024-01-25 01:16:03.803786+06	shurjopay	65b161f2	6
54	1905077	2024-01-25 01:33:54.697124+06	shurjopay	65b16621	4
\.


--
-- Data for Name: requisition; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.requisition (id, requestor_id, source, destination, subject, text, "timestamp", approved_by, bus_type) FROM stdin;
4	69	\N	Coxsbazar 	Nsys Seminar	We join Nsys. need bus.	2022-01-03 11:30:00+06	\N	{mini}
5	69	\N	Green University,  Bangladesh. 	IUPC	In order to join the iupc competition,  we need one mini bus.	2023-09-28 10:30:00+06	\N	{mini}
6	1905084	\N	Beanibazar Upazila Sadar	For leisure tour	hello sir we need bus to go ti sylhet beanibazar veey close to assam	2023-09-14 00:30:00+06	\N	{single_decker,mini}
8	69	\N	bop	b	bbbbb	2023-09-21 08:30:00+06	\N	{single_decker}
9	69	\N	outing	outing	picnic	2023-09-28 06:30:00+06	\N	{mini}
10	69	\N	b	a	c	2023-09-14 09:30:00+06	\N	{single_decker,mini}
11	1905067	\N	UIU	Study Tour	I request for 2 single decker bus for students of cse 19, to go on a study tour	2023-09-15 08:30:00+06	\N	{single_decker}
13	1905067	\N	NSU	inter university programming contest	Need a double decker for contestants	2023-09-23 07:00:00+06	\N	{double_decker}
14	1905088	\N	Mymensingh	Family tour	Need a mini bus to carry my family to mymensingh 	2023-09-16 23:00:00+06	\N	{mini}
15	1905088	\N	AIUB	Debate Competition		2023-09-10 08:30:00+06	\N	{single_decker}
18	1905077	\N	Kathalbagan	Picnic	For entertainment 	2023-09-27 10:30:00+06	\N	{micro}
19	1905077	\N	SUST	Icpc	Programming contest.	2023-09-28 10:30:00+06	\N	{single_decker}
20	1905088	\N	Huq Shaheb er Garage, Shyamoli	Bashay Jabo	Bashay jawar jonno lagbe	2023-09-07 08:30:00+06	\N	{double_decker}
21	1905084	\N	Narsingdi 	hsjskks	shsjsjs	2023-09-08 11:30:00+06	\N	{single_decker,mini}
22	1905077	\N	Purbachal	Icpc	Contest	2023-09-26 08:30:00+06	\N	{single_decker}
23	1905067	\N	Rampal Power Plant	Field trip	we need a microbus for our field trip.	2023-10-15 20:48:00+06	\N	{micro}
24	1905067	\N	Rampal Power Plant	Field trip	we need a microbus for our field trip.	2023-10-15 20:48:00+06	\N	{micro}
25	1905067	\N	Rampal Power plant	Field Trip	We need a micro bus for 5 students for a study trip.	2023-10-15 20:48:00+06	\N	{micro}
26	1905067	\N	Rampal Power plant	Field Trip	We need a micro bus for 5 students for a study trip.	2023-10-15 20:48:00+06	\N	{micro}
27	1905067	\N	Ruppur	Field Trip	We need a micro bus for 5 students for a study trip.	2023-10-15 20:48:00+06	\N	{micro}
28	1905067	\N	Rampal Power plant	Field Trip	We need a micro bus for 5 students for a study trip.	2023-10-15 20:48:00+06	\N	{micro}
2	1905002	Mohammadpur	Dhaka Resort	hello picnic	picnic	2023-09-06 23:32:30.008238+06	reyazul	\N
3	1905002	Dhanmondi	Uttara	subject	text	2023-10-01 16:00:00+06	reyazul	\N
7	1905084	\N	Khilgaon	hello pls	need to go to khilgaon	2023-09-25 08:30:00+06	reyazul	{micro}
12	1905067	\N	Gazipur Resort	Personal Use	I need a micro bus for a family tour	2023-09-08 08:30:00+06	mubasshira	{micro}
16	1905069	\N	Rupgonj Jolsiri	Picnic	Picnic	2023-09-15 08:30:00+06	mashroor	{mini}
17	1905077	\N	Iut	Will give Icpc 	programming contest	2023-09-22 08:30:00+06	reyazul	{micro}
32	pranto	\N	jsjs	sjsk	zjsnsm	2024-01-30 08:30:00+06	\N	{double_decker}
33	pranto	\N	hel	ah	zj	2024-01-25 08:30:00+06	\N	{double_decker}
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
-- Data for Name: session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session (sid, sess, expire) FROM stdin;
\.


--
-- Data for Name: station; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.station (id, name, coords, adjacent_points) FROM stdin;
8	Old Airport 	(23.77178659908652,90.38957499914268)	\N
1	College Gate	(23.769213162447304,90.36876120662684)	\N
2	Station Road	(23.892735315562756,90.40197068534414)	\N
3	Tongi Bazar	(23.88427608752206,90.40045971191294)	\N
4	Abdullahpur	(23.87980639062533,90.40118222387154)	\N
5	Uttara House Building	(23.873819697344935,90.40053785728188)	\N
6	Azampur	(23.86785298269277,90.40022657238241)	\N
7	Shaheen College	(23.775547826528047,90.39189035378897)	\N
9	Ellenbari	(23.76522951056849,90.38907568606375)	\N
10	Aolad Hossian Market	(23.762978573175356,90.38917778985805)	\N
11	Farmgate	(23.75830991006695,90.39006461196334)	\N
12	Malibag Khidma Market	(23.749129653669698,90.41981844420462)	\N
13	Khilgao Railgate	(23.74422274202347,90.42642485418273)	\N
14	Basabo	(23.739739562565465,90.42750217562016)	\N
15	Bouddho Mandir	(23.736287102644095,90.42849412575818)	\N
16	Mugdapara	(23.73125402135349,90.42847070671291)	\N
17	Sanarpar	(23.694910069706566,90.49018171222788)	\N
18	Signboard	(23.69382820912737,90.48070754228206)	\N
19	Saddam Market	(23.6930333006468,90.47294821509882)	\N
20	Matuail Medical	(23.694922870152688,90.46662805325313)	\N
21	Rayerbag	(23.699452593105473,90.45714520603525)	\N
22	Shonir Akhra	(23.702759892542936,90.45028970971552)	\N
23	Kajla	(23.7056566136023,90.4442670782193)	\N
24	Jatrabari	(23.71004890888318,90.43452187613019)	\N
25	Ittefak Mor	(23.721613399553892,90.42134094863007)	\N
26	Arambag	(23.73148111199774,90.42083500748528)	\N
27	Notun Bazar	(23.797803911606113,90.42353036139312)	\N
28	Uttor Badda	(23.78594006738361,90.42564747234172)	\N
29	Moddho Badda	(23.77788437830488,90.42567032546067)	\N
30	Merul Badda	(23.772862356779285,90.42552102012964)	\N
31	Rampura TV Gate	(23.765717111761024,90.42185514176059)	\N
32	Rampura Bazar	(23.761225700270263,90.41929816771406)	\N
33	Abul Hotel	(23.754280372386287,90.41532775209724)	\N
34	Malibag Railgate	(23.74992564121926,90.41283077901616)	\N
35	Mouchak	(23.746596017920087,90.41229675666234)	\N
36	Tajmahal Road	(23.763809074127288,90.36564046785911)	\N
37	Nazrul Islam Road	(23.757614175962193,90.36241335180047)	\N
38	Shankar Bus Stand	(23.750659326938333,90.36841436906487)	\N
39	Dhanmondi 15	(23.744501003619725,90.37244046931268)	\N
40	Jhigatola	(23.73909098406254,90.37553336535188)	\N
41	Mirpur 10	(23.80694289074129,90.3685711078533)	\N
42	Mirpur 2	(23.80498118040957,90.36328393651736)	\N
43	Mirpur 1	(23.798497327205652,90.35316121745808)	\N
44	Mirpur Chinese	(23.794642294364998,90.35335323466074)	\N
45	Ansar Camp	(23.79095839297597,90.35375343466058)	\N
46	Bangla College	(23.78478514989056,90.35379372859546)	\N
47	Kallyanpur	(23.777975490889016,90.36112130222347)	\N
48	Shyamoli Hall	(23.77501389359074,90.3654282978599)	\N
49	Shishumela	(23.77298522787119,90.3673447413414)	\N
50	Rajlokkhi	(23.86427626854673,90.4001008267417)	\N
51	Airport	(23.852043584305772,90.40747424854275)	\N
52	Kaola	(23.84578900317074,90.41256570948558)	\N
53	Khilkhet	(23.829001350312897,90.41999876535472)	\N
54	Bishwaroad	(23.821244902976005,90.4184231223024)	\N
55	Sheora Bazar	(23.818753739058263,90.41486259303835)	\N
56	MES	(23.81686575326826,90.40596761411776)	\N
57	Navy Headquarter	(23.802953981274726,90.4023678965428)	\N
58	Kakoli	(23.79503254223975,90.40088706906629)	\N
59	Chairman Bari	(23.78955650718996,90.40011589790265)	\N
60	Mohakhali	(23.77799128256197,90.39735858707148)	\N
61	Nabisco	(23.769576184918215,90.40101562859505)	\N
62	Satrasta	(23.75740990168624,90.39900644208478)	\N
63	Mogbazar	(23.748637341330323,90.40366410668703)	\N
64	Mirpur 11	(23.815914422939255,90.36613871454468)	\N
65	Pallabi Cinema Hall	(23.819566365373973,90.36516682668837)	\N
66	Kazipara	(23.797147561971236,90.37281478255649)	\N
67	Sheorapara	(23.790388161465135,90.37570727092245)	\N
68	Agargaon	(23.777478142723012,90.38031962673897)	\N
69	Taltola	(23.783510519116227,90.37865196128236)	\N
70	BUET	(23.72772109504178,90.39169264466838)	\N
\.


--
-- Data for Name: student; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student (id, phone, email, password, default_route, name, default_station) FROM stdin;
69     	01234567890	nafiu.grahman@gmail.com	1	3	Based Rahman	63
1905069	01234567894	mhb69@gmail.com	pqr	1	Mashroor Hasan Bhuiyan	7
1905067	01878117218	sojibxaman439@gmail.com	abc	4	MD. ROQUNUZZAMAN SOJIB	27
1905077	01284852645	nafiu.rahhman@gmail.com	xyz	8	Nafiu Rahman	36
1905088	01828282828	mubasshira728@gmail.com	123	6	Mubasshira Musarrat	47
1905082	01521564748	kz.rxl.hsn@gmail.com	rxl69	7	Kazi Reyazul Hasan	12
1905084	01729733687	wasifjalalgalib@gmail.com	bogmbogm2	5	Wasif Jalal	38
\.


--
-- Data for Name: student_feedback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_feedback (id, complainer_id, route, submission_timestamp, concerned_timestamp, text, trip_id, subject, response) FROM stdin;
3	1905084	4	2023-09-06 11:25:48.287028+06	2023-09-01 00:00:00+06	ieieieiehdjdkdks	\N	{bus,staff}	\N
4	1905084	3	2023-09-06 11:36:34.942567+06	2023-09-03 00:00:00+06	jdjdkkw didjd	\N	{bus}	\N
6	1905084	\N	2023-09-06 11:41:12.132757+06	\N	hhjkvgg	\N	{other}	\N
9	69	1	2023-09-06 21:04:17.110769+06	2023-09-05 06:00:00+06	1984: Possibly the most terrifying space photograph ever taken. NASA astronaut Bruce McCandless floats untethered from his spacecraft using only his nitrogen-propelled, hand controlled backpack called a Manned Manoeuvring Unit (MMU) to keep him alive.	\N	{other}	\N
7	1905084	5	2023-09-06 13:17:05.786283+06	2023-09-03 00:00:00+06	হালা আমারে ভাংতি দেয় নাই 😡	\N	{staff}	ভাই টিকেট না বিক্যাশে কিনসেন? কন্ডাক্টরের কাছে ভাংতি চান কেন?
8	69	3	2023-09-06 21:01:31.633662+06	2023-09-01 06:00:00+06	The time table should be changed. So unnecessary to start journey at 6:15AM in the morning. 	\N	{bus}	Thank you for your request. It has automatically been ignored.
10	69	8	2023-09-06 23:27:02.239861+06	2023-09-01 06:00:00+06	driver ashrafur rahman amar tiffin kheye felse	\N	{staff}	\N
11	1905084	3	2023-09-07 03:29:51.973152+06	\N	trrgy	\N	{bus}	\N
12	1905084	3	2023-09-07 04:38:22.389025+06	\N	seat bhanga	\N	{bus}	\N
2	1905084	3	2023-09-06 11:25:01.426082+06	\N	ieieieie	\N	{bus}	what?
13	69	3	2023-09-07 11:00:31.772593+06	2023-09-01 00:00:00+06	baje staff	\N	{staff}	\N
14	1905067	6	2023-09-07 11:10:55.061921+06	2023-09-05 00:00:00+06	Bus changed its route because of a political gathering & missed my location. 	\N	{bus}	\N
16	1905067	6	2023-09-07 11:12:52.902353+06	\N	Bus didn't reach buet in time. Missed ct	\N	{bus}	\N
17	1905067	4	2023-09-07 11:13:30.087775+06	2023-08-24 00:00:00+06	Staff was very rude	\N	{staff}	\N
18	1905067	3	2023-09-07 11:14:10.821911+06	2023-09-04 00:00:00+06	Driver came late	\N	{driver}	\N
20	1905067	7	2023-09-07 11:18:51.84041+06	\N	Can install some fans	\N	{other}	\N
21	1905088	5	2023-09-07 11:25:20.058267+06	2023-09-05 00:00:00+06	Helper was very rude. shouted on me	\N	{staff}	\N
22	1905088	6	2023-09-07 11:26:39.318946+06	2023-09-06 00:00:00+06	Bus left the station earlier than the given time in the morning without any prior notice	\N	{bus}	\N
23	1905088	1	2023-09-07 11:27:26.44088+06	2023-08-16 00:00:00+06	Too crowded. Should assign another bus in this route	\N	{other}	\N
24	69	5	2023-09-07 11:34:00.003955+06	\N	vai amare gali dise ,oi bus e uthum nah ar	\N	{staff}	\N
25	1905077	5	2023-09-07 11:43:47.455913+06	2023-09-05 00:00:00+06	bad seating service	\N	{staff}	\N
15	1905067	5	2023-09-07 11:12:05.993256+06	2023-08-08 00:00:00+06	way too many passengers	\N	{other}	Sorry but we are trying to expand capacity
19	1905067	2	2023-09-07 11:14:55.781888+06	\N	Bus left the station before time in the morning	\N	{bus}	According to our data the bus left in correct time, if you would like to take you claim further then pls contact the authority with definitive evidence
26	1905077	6	2023-09-07 11:44:13.981407+06	2023-09-02 00:00:00+06	no fan in bus	\N	{driver}	we are planning to install new fans next semester, pls be patient till then.
27	1905077	5	2023-09-07 12:00:58.617135+06	2023-09-05 00:00:00+06	rough driving	\N	{staff}	\N
28	1905088	5	2023-09-07 14:39:49.325426+06	2023-09-06 00:00:00+06	rude driver	\N	{driver}	\N
29	1905084	5	2023-09-07 18:31:43.400612+06	2023-09-04 00:00:00+06	no refreshments offered 😤	\N	{other}	\N
30	1905084	5	2023-09-07 18:51:09.219167+06	2023-09-06 00:00:00+06	hdhe	\N	{bus}	\N
31	1905084	5	2023-09-08 00:42:30.790952+06	2023-09-07 00:00:00+06	Did not stop when I asked to	\N	{driver}	\N
32	1905084	5	2023-09-09 09:12:07.12405+06	2023-09-07 00:00:00+06	bhanga bus. sojib jhamela kore window seat niye	\N	{bus}	\N
33	1905077	6	2023-09-11 16:51:13.450342+06	2023-09-11 00:00:00+06	বাসে চড়তে ভাল্লাগে না	\N	{other}	\N
34	1905077	1	2023-09-15 11:46:26.199246+06	2023-09-05 00:00:00+06	Dangerous driving 	\N	{staff}	\N
35	1905077	1	2023-09-15 11:46:46.502356+06	2023-09-05 00:00:00+06	Dangerous driving 	\N	{staff}	\N
36	1905067	1	2024-01-04 20:15:34.335892+06	2023-10-05 11:48:00+06	The driver was driving without any caution. He almost hit a bike on the road. 	\N	{driver}	\N
37	1905067	1	2024-01-04 20:16:01.78843+06	2023-10-05 11:48:00+06	The driver was driving without any caution. He almost hit a bike on the road. 	\N	{driver}	\N
38	1905067	1	2024-01-06 12:38:25.721532+06	2023-10-05 11:48:00+06	The driver was so bad.	\N	{driver}	\N
39	1905067	1	2024-01-06 13:14:21.261369+06	2023-10-05 11:48:00+06	bad driver	\N	{driver}	\N
40	69	5	2024-01-23 17:29:48.807233+06	2024-01-23 00:00:00+06	hdjeikek	\N	{driver,staff}	\N
41	1905067	8	2024-01-23 17:32:26.99375+06	2024-01-19 00:00:00+06	mok marisil	\N	{staff}	\N
47	69	2	2024-01-29 09:42:23.279531+06	2024-01-23 00:00:00+06	Jhamela hoise	\N	{driver}	\N
48	1905077	5	2024-01-31 15:11:46.467135+06	2024-01-17 00:00:00+06	pocha shobai bus er	\N	{driver}	\N
\.


--
-- Data for Name: student_notification; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_notification (id, user_id, text, "timestamp", is_read) FROM stdin;
\.


--
-- Data for Name: ticket; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ticket (student_id, trip_id, purchase_id, is_used, id) FROM stdin;
1905084	\N	51	f	1f176532-22a1-46e3-bd99-bfa9cd299869
1905084	\N	51	f	c99b89c8-c00d-4c81-a5ba-5944c76b1c5a
1905084	\N	51	f	34d6cf97-a2e9-4e04-8c85-6e31eb892b22
1905084	\N	51	f	03d51151-8525-403e-8651-b46bb95ba394
1905084	\N	51	f	da776040-456c-45fe-965f-bbff13269576
1905084	\N	51	f	52b09c9f-643c-4998-bfad-5c39908f8ec4
1905084	\N	51	f	cbda569b-4da6-454d-a7d9-c98308654a08
1905084	\N	51	f	5780cb12-a125-4ed7-ae41-0f392e2c2c34
1905084	\N	51	f	3ea017a7-f998-4307-80e9-c731d7d88868
1905084	\N	51	f	1c89c3fc-b4d9-433f-9e63-5f4864ee6f60
1905084	\N	51	f	14cd2a03-0358-4056-a4ed-1063de7bcb6d
1905084	\N	51	f	bd08b692-6ecc-4d15-a4b1-0082375aa9d9
1905084	\N	51	f	757a6b94-1bf7-483a-b95f-1ba5aea0cf4a
69     	\N	52	f	3ce03833-4888-4c3d-859f-0e9aca093eff
69     	\N	52	f	eeaba65b-9455-4581-b5ff-ba49ca7915fd
69     	\N	52	f	ce0146d6-714a-4327-bd7b-6003984c1a56
69     	\N	52	f	ebede49f-fdcb-4ac4-a6ff-7eb95ef3fd31
69     	\N	52	f	12cd7519-b638-46a5-b9da-0c900d506572
69     	\N	52	f	efbb9a55-61d4-4630-b556-f0ee8ad9e1a6
69     	\N	52	f	fdb17c28-a37a-4d2f-afa8-b6c91a96433d
69     	\N	52	f	e05b75c1-ff87-4d3f-a382-63bc706063ab
1905067	\N	53	f	d004363b-770f-4cee-94db-b9cc072d5e7e
1905077	\N	54	f	4a0d345a-eff3-4821-a37c-68107a378201
1905077	\N	54	f	bb591671-ae91-4998-ab2f-b8bc6d0c0122
1905077	\N	54	f	6d75dca8-24f9-4005-bf80-4cec9ff200a2
1905077	\N	54	f	de74f2b4-549f-4f12-912d-eb178cffcccf
1905084	\N	51	t	33dbe35f-2d62-47d3-9ad2-a65708e85fb8
1905067	1539	53	t	ef57d389-4025-413c-8a8b-6b58f6554cd9
1905067	1539	53	t	9e872f9f-2441-4511-ab93-2d6b086e2a09
1905067	1786	53	t	61d85db4-de4e-462c-8177-17808603a033
1905067	1786	53	t	4d7f86e4-b7a8-4129-ba28-eddd5a2ef24e
1905067	1930	53	t	22dcd7cb-b7e0-4ea0-8a80-0ab6de5c0659
\.


--
-- Data for Name: trip; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trip (id, start_timestamp, route, time_type, time_list, travel_direction, bus, is_default, driver, approved_by, end_timestamp, start_location, end_location, path, is_live, passenger_count, helper) FROM stdin;
1958	2024-01-31 01:34:00.489636+06	5	afternoon	{"(36,\\"2024-02-01 19:40:00+06\\")","(37,\\"2024-02-01 19:50:00+06\\")","(38,\\"2024-02-01 19:55:00+06\\")","(39,\\"2024-02-01 20:00:00+06\\")","(40,\\"2024-02-01 20:07:00+06\\")","(70,\\"2024-02-01 20:10:00+06\\")"}	from_buet	Ba-22-4326	t	rafiqul	nazmul	2024-01-31 01:58:43.640821+06	(23.76237,90.35889)	(23.7278344,90.3910436)	{"(23.7623489,90.358887)","(23.7663533,90.3648367)","(23.7655104,90.3651403)","(23.7646664,90.3654348)","(23.7641944,90.3652159)","(23.7640314,90.3646332)","(23.7638582,90.3640017)","(23.763682,90.3633785)","(23.7635197,90.3628186)","(23.76334,90.3622083)","(23.7631566,90.3616031)","(23.7629762,90.3609855)","(23.7628117,90.3603567)","(23.7626414,90.3597687)","(23.7624553,90.3591464)","(23.7620753,90.3588786)","(23.7615786,90.3589119)","(23.7610516,90.3589305)","(23.7605511,90.3588835)","(23.7600263,90.3589248)","(23.7595375,90.3590761)","(23.7590781,90.3592982)","(23.7586213,90.3595548)","(23.7581814,90.3598812)","(23.7577712,90.3602328)","(23.7574001,90.3606268)","(23.7571153,90.3610577)","(23.7567658,90.3618999)","(23.7562055,90.3625783)","(23.7556434,90.3632366)","(23.75512,90.3638618)","(23.75458,90.3645316)","(23.7540433,90.3651785)","(23.75352,90.3657835)","(23.7529799,90.3664234)","(23.7524978,90.3669876)","(23.7517913,90.3676036)","(23.7511659,90.3680588)","(23.7504509,90.3685497)","(23.7497367,90.3690418)","(23.7490434,90.369525)","(23.74837,90.3699901)","(23.7477591,90.3704005)","(23.7470341,90.3708881)","(23.7463433,90.37136)","(23.7456102,90.3718518)","(23.7449232,90.3723101)","(23.7442483,90.3727416)","(23.7436292,90.3731604)","(23.7429011,90.3736597)","(23.7422153,90.3740487)","(23.7414977,90.3744266)","(23.7407603,90.3748002)","(23.7400468,90.3751518)","(23.7393131,90.3755332)","(23.7385949,90.3759168)","(23.7385433,90.3758267)","(23.7390717,90.3755345)","(23.7395864,90.3752647)","(23.7387134,90.3758541)","(23.7385722,90.3778198)","(23.7388566,90.3795551)","(23.7396279,90.3807628)","(23.7403133,90.3815189)","(23.7406496,90.3831105)","(23.739228,90.3833956)","(23.7379529,90.3837217)","(23.7367137,90.3839936)","(23.7354392,90.3842999)","(23.7341904,90.38461)","(23.7327824,90.3849899)","(23.7325079,90.386185)","(23.7322001,90.387033)","(23.73019,90.3873201)","(23.7286641,90.3883909)","(23.7279262,90.3891317)","(23.7272991,90.389751)","(37.4226711,-122.0849872)","(23.72723,90.38992)","(23.7276533,90.390254)","(23.727735,90.3907998)"}	f	0	reyazul
1004	2024-01-27 23:28:31.997913+06	3	evening	{"(17,\\"2024-02-14 23:30:00+06\\")","(18,\\"2024-02-14 23:45:00+06\\")","(19,\\"2024-02-14 23:48:00+06\\")","(20,\\"2024-02-14 23:50:00+06\\")","(21,\\"2024-02-14 23:52:00+06\\")","(22,\\"2024-02-14 23:54:00+06\\")","(23,\\"2024-02-14 23:56:00+06\\")","(24,\\"2024-02-14 23:58:00+06\\")","(25,\\"2024-02-14 00:00:00+06\\")","(26,\\"2024-02-14 00:02:00+06\\")","(70,\\"2024-02-14 00:04:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-27 23:30:27.272595+06	\N	\N	\N	f	0	rashid56
1038	2024-01-27 23:33:34.268594+06	7	morning	{"(50,\\"2024-02-04 12:40:00+06\\")","(51,\\"2024-02-04 12:42:00+06\\")","(52,\\"2024-02-04 12:43:00+06\\")","(53,\\"2024-02-04 12:46:00+06\\")","(54,\\"2024-02-04 12:47:00+06\\")","(55,\\"2024-02-04 12:48:00+06\\")","(56,\\"2024-02-04 12:50:00+06\\")","(57,\\"2024-02-04 12:52:00+06\\")","(58,\\"2024-02-04 12:53:00+06\\")","(59,\\"2024-02-04 12:54:00+06\\")","(60,\\"2024-02-04 12:56:00+06\\")","(61,\\"2024-02-04 12:58:00+06\\")","(62,\\"2024-02-04 13:00:00+06\\")","(63,\\"2024-02-04 13:02:00+06\\")","(70,\\"2024-02-04 13:00:00+06\\")"}	to_buet	Ba-35-1461	t	sohel55	nazmul	2024-01-27 23:33:45.29544+06	\N	\N	\N	f	0	rashid56
1039	2024-01-27 23:36:13.687176+06	7	afternoon	{"(50,\\"2024-02-04 19:40:00+06\\")","(51,\\"2024-02-04 19:48:00+06\\")","(52,\\"2024-02-04 19:50:00+06\\")","(53,\\"2024-02-04 19:52:00+06\\")","(54,\\"2024-02-04 19:54:00+06\\")","(55,\\"2024-02-04 19:56:00+06\\")","(56,\\"2024-02-04 19:58:00+06\\")","(57,\\"2024-02-04 20:00:00+06\\")","(58,\\"2024-02-04 20:02:00+06\\")","(59,\\"2024-02-04 20:04:00+06\\")","(60,\\"2024-02-04 20:06:00+06\\")","(61,\\"2024-02-04 20:08:00+06\\")","(62,\\"2024-02-04 20:10:00+06\\")","(63,\\"2024-02-04 20:12:00+06\\")","(70,\\"2024-02-04 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	sohel55	nazmul	2024-01-27 23:36:26.395124+06	\N	\N	\N	f	0	rashid56
1040	2024-01-27 23:43:56.679781+06	7	evening	{"(50,\\"2024-02-04 23:30:00+06\\")","(51,\\"2024-02-04 23:38:00+06\\")","(52,\\"2024-02-04 23:40:00+06\\")","(53,\\"2024-02-04 23:42:00+06\\")","(54,\\"2024-02-04 23:44:00+06\\")","(55,\\"2024-02-04 23:46:00+06\\")","(56,\\"2024-02-04 23:48:00+06\\")","(57,\\"2024-02-04 23:50:00+06\\")","(58,\\"2024-02-04 23:52:00+06\\")","(59,\\"2024-02-04 23:54:00+06\\")","(60,\\"2024-02-04 23:56:00+06\\")","(61,\\"2024-02-04 23:58:00+06\\")","(62,\\"2024-02-04 00:00:00+06\\")","(63,\\"2024-02-04 00:02:00+06\\")","(70,\\"2024-02-04 00:04:00+06\\")"}	from_buet	Ba-35-1461	t	sohel55	nazmul	2024-01-27 23:48:50.815707+06	\N	\N	\N	f	0	rashid56
1098	2024-01-28 00:18:54.862311+06	3	morning	{"(17,\\"2024-02-17 12:40:00+06\\")","(18,\\"2024-02-17 12:42:00+06\\")","(19,\\"2024-02-17 12:44:00+06\\")","(20,\\"2024-02-17 12:46:00+06\\")","(21,\\"2024-02-17 12:48:00+06\\")","(22,\\"2024-02-17 12:50:00+06\\")","(23,\\"2024-02-17 12:52:00+06\\")","(24,\\"2024-02-17 12:54:00+06\\")","(25,\\"2024-02-17 12:57:00+06\\")","(26,\\"2024-02-17 13:00:00+06\\")","(70,\\"2024-02-17 13:15:00+06\\")"}	to_buet	Ba-35-1461	t	altaf	nazmul	2024-01-28 00:23:03.782982+06	\N	\N	\N	f	0	rashid56
1099	2024-01-28 00:24:57.065157+06	3	afternoon	{"(17,\\"2024-02-17 19:40:00+06\\")","(18,\\"2024-02-17 19:55:00+06\\")","(19,\\"2024-02-17 19:58:00+06\\")","(20,\\"2024-02-17 20:00:00+06\\")","(21,\\"2024-02-17 20:02:00+06\\")","(22,\\"2024-02-17 20:04:00+06\\")","(23,\\"2024-02-17 20:06:00+06\\")","(24,\\"2024-02-17 20:08:00+06\\")","(25,\\"2024-02-17 20:10:00+06\\")","(26,\\"2024-02-17 20:12:00+06\\")","(70,\\"2024-02-17 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	altaf	nazmul	2024-01-28 00:30:26.241063+06	\N	\N	\N	f	0	rashid56
1941	2024-01-30 18:51:48.390011+06	7	evening	{"(50,\\"2024-01-30 23:30:00+06\\")","(51,\\"2024-01-30 23:38:00+06\\")","(52,\\"2024-01-30 23:40:00+06\\")","(53,\\"2024-01-30 23:42:00+06\\")","(54,\\"2024-01-30 23:44:00+06\\")","(55,\\"2024-01-30 23:46:00+06\\")","(56,\\"2024-01-30 23:48:00+06\\")","(57,\\"2024-01-30 23:50:00+06\\")","(58,\\"2024-01-30 23:52:00+06\\")","(59,\\"2024-01-30 23:54:00+06\\")","(60,\\"2024-01-30 23:56:00+06\\")","(61,\\"2024-01-30 23:58:00+06\\")","(62,\\"2024-01-30 00:00:00+06\\")","(63,\\"2024-01-30 00:02:00+06\\")","(70,\\"2024-01-30 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	sohel55	\N	2024-01-30 18:55:06.87056+06	(23.7664933,90.3647317)	(23.7664737,90.3647329)	{"(23.7664569,90.3647362)"}	f	0	nasir81
1990	2024-01-30 18:59:28.377695+06	1	morning	{"(1,\\"2024-02-05 12:15:00+06\\")","(2,\\"2024-02-05 12:18:00+06\\")","(3,\\"2024-02-05 12:20:00+06\\")","(4,\\"2024-02-05 12:23:00+06\\")","(5,\\"2024-02-05 12:26:00+06\\")","(6,\\"2024-02-05 12:29:00+06\\")","(7,\\"2024-02-05 12:49:00+06\\")","(8,\\"2024-02-05 12:51:00+06\\")","(9,\\"2024-02-05 12:53:00+06\\")","(10,\\"2024-02-05 12:55:00+06\\")","(11,\\"2024-02-05 12:58:00+06\\")","(70,\\"2024-02-05 13:05:00+06\\")"}	to_buet	Ba-19-0569	t	altaf	nazmul	2024-01-30 19:02:06.40486+06	(23.7664933,90.3647317)	(23.7664716,90.3647332)	{"(23.7664933,90.3647317)"}	f	0	siddiq2
1155	2024-01-28 02:27:41.406627+06	6	morning	{"(41,\\"2024-01-29 12:40:00+06\\")","(42,\\"2024-01-29 12:42:00+06\\")","(43,\\"2024-01-29 12:45:00+06\\")","(44,\\"2024-01-29 12:47:00+06\\")","(45,\\"2024-01-29 12:49:00+06\\")","(46,\\"2024-01-29 12:51:00+06\\")","(47,\\"2024-01-29 12:52:00+06\\")","(48,\\"2024-01-29 12:53:00+06\\")","(49,\\"2024-01-29 12:54:00+06\\")","(70,\\"2024-01-29 13:10:00+06\\")"}	to_buet	Ba-17-2081	t	altaf	nazmul	2024-01-28 02:28:25.45167+06	\N	\N	{"(23.7646853,90.3621754)","(23.7647807,90.3633323)","(23.7638179,90.3638189)"}	f	0	rashid56
1156	2024-01-28 02:40:01.793866+06	6	afternoon	{"(41,\\"2024-01-29 19:40:00+06\\")","(42,\\"2024-01-29 19:56:00+06\\")","(43,\\"2024-01-29 19:58:00+06\\")","(44,\\"2024-01-29 20:00:00+06\\")","(45,\\"2024-01-29 20:02:00+06\\")","(46,\\"2024-01-29 20:04:00+06\\")","(47,\\"2024-01-29 20:06:00+06\\")","(48,\\"2024-01-29 20:08:00+06\\")","(49,\\"2024-01-29 20:10:00+06\\")","(70,\\"2024-01-29 20:12:00+06\\")"}	from_buet	Ba-17-2081	t	altaf	nazmul	2024-01-28 02:41:04.128471+06	\N	\N	{"(23.764785,90.362795)","(23.764785,90.362795)","(23.7641433,90.3635413)","(23.7641433,90.3635413)","(23.7629328,90.3644588)","(23.7629328,90.3644588)","(23.7619764,90.3647657)","(23.7619764,90.3647657)"}	f	0	rashid56
1140	2024-01-28 03:05:49.773112+06	8	morning	{"(64,\\"2024-01-28 12:10:00+06\\")","(65,\\"2024-01-28 12:13:00+06\\")","(66,\\"2024-01-28 12:18:00+06\\")","(67,\\"2024-01-28 12:20:00+06\\")","(68,\\"2024-01-28 12:22:00+06\\")","(69,\\"2024-01-28 12:25:00+06\\")","(70,\\"2024-01-28 12:40:00+06\\")"}	to_buet	Ba-83-8014	t	ibrahim	nazmul	2024-01-28 03:06:57.62416+06	(23.762675,90.3645433)	(23.7610135,90.3651185)	{"(23.7626585,90.364548)","(23.7649167,90.363245)","(23.7639681,90.3636351)","(23.7626791,90.3645418)","(23.7617005,90.3648539)"}	f	0	mahbub777
1203	2024-01-28 03:35:02.834051+06	6	morning	{"(41,\\"2024-02-01 12:40:00+06\\")","(42,\\"2024-02-01 12:42:00+06\\")","(43,\\"2024-02-01 12:45:00+06\\")","(44,\\"2024-02-01 12:47:00+06\\")","(45,\\"2024-02-01 12:49:00+06\\")","(46,\\"2024-02-01 12:51:00+06\\")","(47,\\"2024-02-01 12:52:00+06\\")","(48,\\"2024-02-01 12:53:00+06\\")","(49,\\"2024-02-01 12:54:00+06\\")","(70,\\"2024-02-01 13:10:00+06\\")"}	to_buet	Ba-48-5757	t	ibrahim	nazmul	2024-01-28 03:35:45.077402+06	(23.76481,90.36288)	(23.7623159,90.3646402)	{"(23.7648229,90.3629289)","(23.763818,90.3638189)","(23.7624585,90.3646186)"}	f	0	rashid56
1141	2024-01-28 03:18:47.160923+06	8	afternoon	{"(64,\\"2024-01-28 19:40:00+06\\")","(65,\\"2024-01-28 19:55:00+06\\")","(66,\\"2024-01-28 19:58:00+06\\")","(67,\\"2024-01-28 20:01:00+06\\")","(68,\\"2024-01-28 20:04:00+06\\")","(69,\\"2024-01-28 20:07:00+06\\")","(70,\\"2024-01-28 20:10:00+06\\")"}	from_buet	Ba-83-8014	t	ibrahim	nazmul	2024-01-28 03:19:30.927914+06	(23.7607998,90.3651584)	(23.7632479,90.3643324)	{"(23.7608562,90.3651593)","(23.7646898,90.3623264)","(23.7647391,90.3633399)","(23.7637288,90.3636801)"}	f	0	mahbub777
1142	2024-01-28 03:30:32.69161+06	8	evening	{"(64,\\"2024-01-28 23:30:00+06\\")","(65,\\"2024-01-28 23:45:00+06\\")","(66,\\"2024-01-28 23:48:00+06\\")","(67,\\"2024-01-28 23:51:00+06\\")","(68,\\"2024-01-28 23:54:00+06\\")","(69,\\"2024-01-28 23:57:00+06\\")","(70,\\"2024-01-28 00:00:00+06\\")"}	from_buet	Ba-83-8014	t	ibrahim	nazmul	2024-01-28 03:31:40.217163+06	(23.7630383,90.364425)	(23.7615237,90.3649582)	{"(23.7630204,90.3644298)","(23.76468,90.36243)","(23.7645307,90.3634049)","(23.7638345,90.3641268)","(23.7623752,90.3646502)"}	f	0	mahbub777
1157	2024-01-28 02:49:23.596861+06	6	evening	{"(41,\\"2024-01-29 23:30:00+06\\")","(42,\\"2024-01-29 23:46:00+06\\")","(43,\\"2024-01-29 23:48:00+06\\")","(44,\\"2024-01-29 23:50:00+06\\")","(45,\\"2024-01-29 23:52:00+06\\")","(46,\\"2024-01-29 23:54:00+06\\")","(47,\\"2024-01-29 23:56:00+06\\")","(48,\\"2024-01-29 23:58:00+06\\")","(49,\\"2024-01-29 00:00:00+06\\")","(70,\\"2024-01-29 00:02:00+06\\")"}	from_buet	Ba-17-2081	t	altaf	nazmul	2024-01-28 02:50:10.720968+06	\N	(23.7383,90.44334)	{"(23.764715,90.3625517)","(23.764715,90.3625517)","(23.764715,90.3625517)","(23.7638773,90.3640616)","(23.7638773,90.3640616)","(23.7638773,90.3640616)","(23.7630047,90.3644121)","(23.7630047,90.3644121)","(23.7630047,90.3644121)"}	f	0	rashid56
1162	2024-01-28 03:52:19.424902+06	1	afternoon	{"(1,\\"2024-01-29 19:40:00+06\\")","(2,\\"2024-01-29 19:47:00+06\\")","(3,\\"2024-01-29 19:50:00+06\\")","(4,\\"2024-01-29 19:52:00+06\\")","(5,\\"2024-01-29 19:54:00+06\\")","(6,\\"2024-01-29 20:06:00+06\\")","(7,\\"2024-01-29 20:09:00+06\\")","(8,\\"2024-01-29 20:12:00+06\\")","(9,\\"2024-01-29 20:15:00+06\\")","(10,\\"2024-01-29 20:18:00+06\\")","(11,\\"2024-01-29 20:21:00+06\\")","(70,\\"2024-01-29 20:24:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	2024-01-28 04:24:11.687318+06	(23.75632,90.3641017)	(23.7275826,90.3917008)	{"(23.75632,90.3641017)","(23.7552009,90.3641389)","(23.7544482,90.3647013)","(23.7536596,90.3656218)","(23.7528312,90.3666003)","(23.7519332,90.3674972)","(23.7511598,90.3680533)","(23.7502049,90.3687171)","(23.7491714,90.3694372)","(23.7483965,90.3699624)","(23.7474082,90.3706356)","(23.7463798,90.3713339)","(23.7455886,90.3718562)","(23.7446149,90.3725005)","(23.7438287,90.3730144)","(23.7428648,90.3736806)","(23.7420425,90.374115)","(23.7410082,90.3746741)","(23.7401806,90.3750763)","(23.7391616,90.3756091)","(23.7384099,90.3765045)","(23.7385368,90.3775494)","(23.7387081,90.3788031)","(23.7388976,90.3797904)","(23.7392359,90.380841)","(23.7401354,90.3806777)","(23.740358,90.3818204)","(23.7405714,90.3829354)","(23.7395909,90.3833197)","(23.7386776,90.3835081)","(23.7377446,90.3837713)","(23.736841,90.3839697)","(23.7359126,90.3841714)","(23.7350143,90.384413)","(23.7340661,90.3846397)","(23.7331694,90.3848863)","(23.7324898,90.385719)","(23.7325996,90.3867607)","(23.7314599,90.386967)","(23.7304914,90.3872093)","(23.7296013,90.387629)","(23.7287833,90.3882836)","(23.7280026,90.3890557)","(23.7273257,90.3897197)","(23.7277163,90.3907071)","(23.7280587,90.3916682)"}	f	0	farid99
1163	2024-01-28 04:24:47.12721+06	1	evening	{"(1,\\"2024-01-29 23:30:00+06\\")","(2,\\"2024-01-29 23:37:00+06\\")","(3,\\"2024-01-29 23:40:00+06\\")","(4,\\"2024-01-29 23:42:00+06\\")","(5,\\"2024-01-29 23:44:00+06\\")","(6,\\"2024-01-29 23:56:00+06\\")","(7,\\"2024-01-29 23:59:00+06\\")","(8,\\"2024-01-29 00:02:00+06\\")","(9,\\"2024-01-29 00:05:00+06\\")","(10,\\"2024-01-29 00:08:00+06\\")","(11,\\"2024-01-29 00:11:00+06\\")","(70,\\"2024-01-29 00:14:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	2024-01-28 04:38:22.901212+06	(23.7276,90.3917)	(23.74363,90.37316)	{"(23.7276,90.3917)","(23.7647037,90.3622592)","(23.7648629,90.3633074)","(23.7638522,90.3639699)","(23.7629304,90.3644598)","(23.762062,90.3647632)","(23.7611915,90.3650536)","(23.7601869,90.3654399)","(23.7593104,90.3657095)","(23.758807,90.3645671)","(23.7582435,90.3634954)","(23.7571685,90.3638249)","(23.7560853,90.3641782)","(23.7550852,90.3640086)","(23.7542803,90.3649014)","(23.7534304,90.3658863)","(23.7525971,90.3668714)","(23.7516004,90.367748)","(23.7505598,90.3684734)","(23.7495101,90.3691982)","(23.7484634,90.3699249)","(23.7474068,90.3706366)","(23.7463784,90.3713349)","(23.7453051,90.3720566)","(23.744265,90.3727299)"}	f	0	farid99
1179	2024-01-28 04:39:14.082505+06	6	morning	{"(41,\\"2024-01-30 12:40:00+06\\")","(42,\\"2024-01-30 12:42:00+06\\")","(43,\\"2024-01-30 12:45:00+06\\")","(44,\\"2024-01-30 12:47:00+06\\")","(45,\\"2024-01-30 12:49:00+06\\")","(46,\\"2024-01-30 12:51:00+06\\")","(47,\\"2024-01-30 12:52:00+06\\")","(48,\\"2024-01-30 12:53:00+06\\")","(49,\\"2024-01-30 12:54:00+06\\")","(70,\\"2024-01-30 13:10:00+06\\")"}	to_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-28 04:41:34.665157+06	(23.743595,90.3731833)	(23.7594097,90.3656727)	{"(23.743595,90.3731833)","(23.7645149,90.3634097)","(23.7635965,90.3642248)","(23.7626683,90.3645331)","(23.7615213,90.3649592)","(23.760607,90.3652536)","(23.7597444,90.3655642)"}	f	0	khairul
1180	2024-01-28 04:43:25.349017+06	6	afternoon	{"(41,\\"2024-01-30 19:40:00+06\\")","(42,\\"2024-01-30 19:56:00+06\\")","(43,\\"2024-01-30 19:58:00+06\\")","(44,\\"2024-01-30 20:00:00+06\\")","(45,\\"2024-01-30 20:02:00+06\\")","(46,\\"2024-01-30 20:04:00+06\\")","(47,\\"2024-01-30 20:06:00+06\\")","(48,\\"2024-01-30 20:08:00+06\\")","(49,\\"2024-01-30 20:10:00+06\\")","(70,\\"2024-01-30 20:12:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-28 05:07:47.276301+06	(23.76293,90.36446)	(23.7275691,90.3917004)	{"(23.7629215,90.3644627)","(23.761893,90.3648211)","(23.760958,90.3651252)","(23.7598395,90.3655478)","(23.7590257,90.3650313)","(23.7583038,90.3636066)","(23.757252,90.3637957)","(23.7561769,90.364146)","(23.7551482,90.3640747)","(23.7540848,90.3651296)","(23.7529648,90.3664414)","(23.7517438,90.3676471)","(23.7503818,90.3685942)","(23.7490333,90.3695325)","(23.7482115,90.370075)","(23.7469167,90.3709675)","(23.7460972,90.3714986)","(23.7448431,90.372356)","(23.7440218,90.3728745)","(23.7426887,90.3737957)","(23.7418545,90.3741857)","(23.7404619,90.374948)","(23.7396228,90.3753398)","(23.7384031,90.376188)","(23.7384991,90.3771824)","(23.7386299,90.3782604)","(23.738924,90.3798963)","(23.739104,90.380962)","(23.7401694,90.3808655)","(23.740456,90.3823275)","(23.7399628,90.3832297)","(23.7388421,90.3834792)","(23.7376836,90.3837859)","(23.7364057,90.3840543)","(23.7352299,90.3843543)","(23.7339625,90.3846692)","(23.7327725,90.3850195)","(23.7325149,90.3861182)","(23.7320907,90.387031)","(23.7303474,90.3872618)","(23.7294433,90.3877279)","(23.7286687,90.3883896)","(23.7279292,90.3891291)","(23.727264,90.3898125)","(23.7279039,90.3912376)"}	f	0	khairul
1181	2024-01-28 05:14:11.476372+06	6	evening	{"(41,\\"2024-01-30 23:30:00+06\\")","(42,\\"2024-01-30 23:46:00+06\\")","(43,\\"2024-01-30 23:48:00+06\\")","(44,\\"2024-01-30 23:50:00+06\\")","(45,\\"2024-01-30 23:52:00+06\\")","(46,\\"2024-01-30 23:54:00+06\\")","(47,\\"2024-01-30 23:56:00+06\\")","(48,\\"2024-01-30 23:58:00+06\\")","(49,\\"2024-01-30 00:00:00+06\\")","(70,\\"2024-01-30 00:02:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-28 05:24:01.704883+06	(23.7605667,90.3652883)	(23.7335124,90.3847891)	{"(23.760503,90.3653183)","(23.7594967,90.3656476)","(23.7587519,90.3644617)","(23.7578897,90.3635623)","(23.7568074,90.3639391)","(23.7557618,90.364289)","(23.7547689,90.3642993)","(23.7541415,90.3650692)","(23.7530767,90.3663061)","(23.7519004,90.3675201)","(23.7511399,90.368056)","(23.7498637,90.368954)","(23.7490843,90.3694787)","(23.7477634,90.3703976)","(23.7469662,90.370914)","(23.74566,90.3718175)","(23.7442341,90.3727505)","(23.7428323,90.3737021)","(23.7414635,90.3744477)","(23.7405702,90.3748659)","(23.7392135,90.3755876)","(23.7384338,90.3760968)","(23.7384761,90.3771184)","(23.7386995,90.3787562)","(23.7388878,90.379826)","(23.739499,90.3807819)","(23.7402677,90.3813673)","(23.740556,90.3828572)","(23.7396403,90.3833063)","(23.7384407,90.3835694)","(23.7371857,90.3838975)","(23.7359756,90.3841543)","(23.7347394,90.3844857)","(23.7335124,90.3847891)"}	f	0	khairul
1991	2024-01-30 19:02:09.106701+06	1	afternoon	{"(1,\\"2024-02-05 19:40:00+06\\")","(2,\\"2024-02-05 19:47:00+06\\")","(3,\\"2024-02-05 19:50:00+06\\")","(4,\\"2024-02-05 19:52:00+06\\")","(5,\\"2024-02-05 19:54:00+06\\")","(6,\\"2024-02-05 20:06:00+06\\")","(7,\\"2024-02-05 20:09:00+06\\")","(8,\\"2024-02-05 20:12:00+06\\")","(9,\\"2024-02-05 20:15:00+06\\")","(10,\\"2024-02-05 20:18:00+06\\")","(11,\\"2024-02-05 20:21:00+06\\")","(70,\\"2024-02-05 20:24:00+06\\")"}	from_buet	Ba-19-0569	t	altaf	nazmul	2024-01-30 19:09:06.146212+06	(23.7664716,90.3647332)	(23.7664916,90.3647319)	{"(23.7664933,90.3647317)"}	f	0	siddiq2
1133	2024-01-28 11:06:01.536329+06	6	evening	{"(41,\\"2024-01-28 23:30:00+06\\")","(42,\\"2024-01-28 23:46:00+06\\")","(43,\\"2024-01-28 23:48:00+06\\")","(44,\\"2024-01-28 23:50:00+06\\")","(45,\\"2024-01-28 23:52:00+06\\")","(46,\\"2024-01-28 23:54:00+06\\")","(47,\\"2024-01-28 23:56:00+06\\")","(48,\\"2024-01-28 23:58:00+06\\")","(49,\\"2024-01-28 00:00:00+06\\")","(70,\\"2024-01-28 00:02:00+06\\")"}	from_buet	Ba-17-2081	t	arif43	nazmul	2024-01-28 11:47:17.242132+06	(23.7284663,90.385963)	(23.7626902,90.3702105)	{"(23.72896666,90.38572278)","(23.73013902,90.3858085)","(23.73133374,90.38525864)","(23.73228998,90.38525799)","(23.73345972,90.38499298)","(23.73433992,90.38448765)","(23.73529561,90.38428382)","(23.73645817,90.38395122)","(23.73757092,90.38385736)","(23.73845939,90.38358146)","(23.7393573,90.38324932)","(23.74023132,90.38297697)","(23.74118056,90.38277456)","(23.74219873,90.38249032)","(23.74327511,90.38224412)","(23.74426002,90.38203039)","(23.74584715,90.3814472)","(23.74677089,90.38103901)","(23.74814029,90.3802901)","(23.74922168,90.37977198)","(23.7506087,90.37874385)","(23.75136046,90.37812954)","(23.75348352,90.37678021)","(23.75473408,90.37604626)","(23.75551876,90.37549925)","(23.75640003,90.37514729)","(23.75728416,90.37467067)","(23.75820697,90.37434126)","(23.75890593,90.3735953)","(23.75976808,90.37309223)","(23.76136498,90.37218037)","(23.76163291,90.37113577)","(23.76246582,90.37069227)","(23.76218281,90.36974614)"}	f	0	abdulbari4
1456	2024-01-28 17:53:36.383554+06	2	afternoon	{"(12,\\"2024-01-29 19:40:00+06\\")","(13,\\"2024-01-29 19:52:00+06\\")","(14,\\"2024-01-29 19:54:00+06\\")","(15,\\"2024-01-29 19:57:00+06\\")","(16,\\"2024-01-29 20:00:00+06\\")","(70,\\"2024-01-29 20:03:00+06\\")"}	from_buet	Ba-19-0569	t	altaf	mashroor	2024-01-28 17:56:31.342259+06	(23.7326599,90.3851097)	(23.7279021,90.3891548)	{"(23.732575,90.3851479)","(23.7325197,90.3861528)","(23.7325197,90.3861528)","(23.7325599,90.3871496)","(23.7325599,90.3871496)","(23.7316105,90.3869601)","(23.7316105,90.3869601)","(23.7305366,90.387193)","(23.7305366,90.387193)","(23.7296208,90.3876182)","(23.7296208,90.3876182)","(23.728753,90.3883114)","(23.728753,90.3883114)","(23.7279679,90.3890902)","(23.7279679,90.3890902)"}	f	0	ASADUZZAMAN
1455	2024-01-28 19:18:40.65915+06	2	morning	{"(12,\\"2024-01-29 12:55:00+06\\")","(13,\\"2024-01-29 12:57:00+06\\")","(14,\\"2024-01-29 12:59:00+06\\")","(15,\\"2024-01-29 13:01:00+06\\")","(16,\\"2024-01-29 13:03:00+06\\")","(70,\\"2024-01-29 13:15:00+06\\")"}	to_buet	Ba-19-0569	t	altaf	mashroor	2024-01-28 19:21:30.530991+06	(23.7276,90.3917)	(23.8743234,90.3888165)	{"(23.7275558,90.3917032)","(23.87425,90.3848517)","(23.8742717,90.3859748)","(23.8742865,90.3871164)","(23.8743101,90.3882773)"}	f	0	ASADUZZAMAN
1539	2024-01-28 23:09:32.395969+06	2	evening	{"(12,\\"2024-01-29 23:30:00+06\\")","(13,\\"2024-01-29 23:42:00+06\\")","(14,\\"2024-01-29 23:45:00+06\\")","(15,\\"2024-01-29 23:48:00+06\\")","(16,\\"2024-01-29 23:51:00+06\\")","(70,\\"2024-01-29 23:54:00+06\\")"}	from_buet	Ba-69-8288	t	sohel55	\N	2024-01-28 23:11:44.565029+06	(23.7626813,90.3702191)	(23.7626943,90.3702246)	{}	f	0	mahbub777
1667	2024-01-29 13:25:44.736076+06	8	afternoon	{"(64,\\"2024-01-29 19:40:00+06\\")","(65,\\"2024-01-29 19:55:00+06\\")","(66,\\"2024-01-29 19:58:00+06\\")","(67,\\"2024-01-29 20:01:00+06\\")","(68,\\"2024-01-29 20:04:00+06\\")","(69,\\"2024-01-29 20:07:00+06\\")","(70,\\"2024-01-29 20:10:00+06\\")"}	from_buet	Ba-93-6087	t	altaf	\N	2024-01-29 14:12:37.207573+06	(23.7266832,90.3879756)	(37.3307017,-122.0416992)	{"(37.421998333333335,-122.084)","(37.412275,-122.08192166666667)","(37.41010333333333,-122.07694333333333)","(37.40792166666667,-122.06673)","(37.403758333333336,-122.05173833333333)","(37.399258333333336,-122.03277)","(37.399258333333336,-122.03277)","(37.39700166666667,-122.01190166666666)","(37.33032,-122.04479)","(37.33071833333333,-122.04375166666667)","(37.33071,-122.04258)"}	f	0	siddiq2
1786	2024-01-29 15:08:16.186189+06	4	morning	{"(27,\\"2024-01-29 12:40:00+06\\")","(28,\\"2024-01-29 12:42:00+06\\")","(29,\\"2024-01-29 12:44:00+06\\")","(30,\\"2024-01-29 12:46:00+06\\")","(31,\\"2024-01-29 12:50:00+06\\")","(32,\\"2024-01-29 12:52:00+06\\")","(33,\\"2024-01-29 12:54:00+06\\")","(34,\\"2024-01-29 12:58:00+06\\")","(35,\\"2024-01-29 13:00:00+06\\")","(70,\\"2024-01-29 13:10:00+06\\")"}	to_buet	BA-01-2345	t	altaf	reyazul	2024-01-29 15:14:46.6046+06	(23.7267164,90.3881888)	(23.7647567,90.360895)	{"(23.764756666666667,90.360895)","(23.764756666666667,90.360895)","(23.764756666666667,90.360895)"}	f	0	alamgir
1787	2024-01-29 15:14:51.580955+06	4	afternoon	{"(27,\\"2024-01-29 19:40:00+06\\")","(28,\\"2024-01-29 19:50:00+06\\")","(29,\\"2024-01-29 19:52:00+06\\")","(30,\\"2024-01-29 19:54:00+06\\")","(31,\\"2024-01-29 19:56:00+06\\")","(32,\\"2024-01-29 19:58:00+06\\")","(33,\\"2024-01-29 20:00:00+06\\")","(34,\\"2024-01-29 20:02:00+06\\")","(35,\\"2024-01-29 20:04:00+06\\")","(70,\\"2024-01-29 20:06:00+06\\")"}	from_buet	BA-01-2345	t	altaf	reyazul	2024-01-29 23:18:22.158268+06	(23.7647567,90.360895)	(23.7625974,90.3701842)	{"(23.76468,90.36215)","(23.76468,90.36215)","(23.76468,90.36215)","(23.764895,90.36317)","(23.764895,90.36317)","(23.764895,90.36317)","(23.765118333333334,90.36412833333333)","(23.765118333333334,90.36412833333333)","(23.765118333333334,90.36412833333333)","(23.764333333333333,90.36475666666666)","(23.764333333333333,90.36475666666666)","(23.764333333333333,90.36475666666666)","(23.76392,90.36567833333334)","(23.76392,90.36567833333334)","(23.76392,90.36567833333334)","(23.763133333333332,90.36701166666667)","(23.763133333333332,90.36701166666667)","(23.763133333333332,90.36701166666667)","(23.763403333333333,90.36802833333333)","(23.763403333333333,90.36802833333333)","(23.763403333333333,90.36802833333333)"}	f	0	alamgir
1939	2024-01-30 00:56:29.07057+06	7	morning	{"(50,\\"2024-01-30 12:40:00+06\\")","(51,\\"2024-01-30 12:42:00+06\\")","(52,\\"2024-01-30 12:43:00+06\\")","(53,\\"2024-01-30 12:46:00+06\\")","(54,\\"2024-01-30 12:47:00+06\\")","(55,\\"2024-01-30 12:48:00+06\\")","(56,\\"2024-01-30 12:50:00+06\\")","(57,\\"2024-01-30 12:52:00+06\\")","(58,\\"2024-01-30 12:53:00+06\\")","(59,\\"2024-01-30 12:54:00+06\\")","(60,\\"2024-01-30 12:56:00+06\\")","(61,\\"2024-01-30 12:58:00+06\\")","(62,\\"2024-01-30 13:00:00+06\\")","(63,\\"2024-01-30 13:02:00+06\\")","(70,\\"2024-01-30 13:00:00+06\\")"}	to_buet	Ba-46-1334	t	sohel55	\N	2024-01-30 02:00:17.416698+06	(23.7626292,90.3702478)	(23.7626699,90.3702059)	{"(23.874325,90.3888517)","(23.8743526,90.3901666)","(23.874255,90.3850317)","(23.874285,90.3870576)","(23.8743099,90.3882428)","(23.8743416,90.3893562)","(23.8743567,90.3905061)","(23.87438,90.3915867)","(23.87439,90.3926017)","(23.8744091,90.3937183)","(23.8744506,90.3949697)","(23.8745025,90.3961401)","(23.8745545,90.3973035)","(23.8746112,90.3984493)","(23.87462,90.3995454)","(23.87466,90.4006463)","(23.8735066,90.4007136)","(37.4226711,-122.0849872)","(23.7583291,90.3786724)","(23.8742593,90.3851502)","(23.8742757,90.3862376)","(23.8742901,90.3873217)","(23.8743101,90.3883149)","(23.8743435,90.3894298)","(23.874407,90.3937895)","(23.8744109,90.3940086)","(23.8744577,90.3950737)","(23.8745055,90.3961643)","(23.8745501,90.3971665)","(23.87462,90.399455)"}	f	0	nasir81
1940	2024-01-30 18:42:57.389505+06	7	afternoon	{"(50,\\"2024-01-30 19:40:00+06\\")","(51,\\"2024-01-30 19:48:00+06\\")","(52,\\"2024-01-30 19:50:00+06\\")","(53,\\"2024-01-30 19:52:00+06\\")","(54,\\"2024-01-30 19:54:00+06\\")","(55,\\"2024-01-30 19:56:00+06\\")","(56,\\"2024-01-30 19:58:00+06\\")","(57,\\"2024-01-30 20:00:00+06\\")","(58,\\"2024-01-30 20:02:00+06\\")","(59,\\"2024-01-30 20:04:00+06\\")","(60,\\"2024-01-30 20:06:00+06\\")","(61,\\"2024-01-30 20:08:00+06\\")","(62,\\"2024-01-30 20:10:00+06\\")","(63,\\"2024-01-30 20:12:00+06\\")","(70,\\"2024-01-30 20:14:00+06\\")"}	from_buet	Ba-46-1334	t	sohel55	\N	2024-01-30 18:50:36.374076+06	(23.7664933,90.3647317)	(23.7664916,90.3647319)	{"(23.7664083,90.364746)"}	f	0	nasir81
1992	2024-01-30 19:09:14.244506+06	1	evening	{"(1,\\"2024-02-05 23:30:00+06\\")","(2,\\"2024-02-05 23:37:00+06\\")","(3,\\"2024-02-05 23:40:00+06\\")","(4,\\"2024-02-05 23:42:00+06\\")","(5,\\"2024-02-05 23:44:00+06\\")","(6,\\"2024-02-05 23:56:00+06\\")","(7,\\"2024-02-05 23:59:00+06\\")","(8,\\"2024-02-05 00:02:00+06\\")","(9,\\"2024-02-05 00:05:00+06\\")","(10,\\"2024-02-05 00:08:00+06\\")","(11,\\"2024-02-05 00:11:00+06\\")","(70,\\"2024-02-05 00:14:00+06\\")"}	from_buet	Ba-19-0569	t	altaf	nazmul	2024-01-30 20:12:21.131647+06	(23.7663984,90.3647428)	(23.7666283,90.3646967)	{"(23.7633199,90.3621187)","(23.7664933,90.3647317)","(23.7660378,90.3649393)","(23.7655868,90.3651079)","(23.7647904,90.3653949)","(23.7643363,90.3655313)","(23.7641401,90.3650102)","(23.7639583,90.3643684)","(23.7637966,90.3637644)","(23.7635315,90.3628686)","(23.7631418,90.3615597)","(23.7628039,90.3603286)","(23.7624547,90.3591464)","(23.7619579,90.3588889)","(23.7666283,90.3646967)"}	f	0	siddiq2
1933	2024-01-31 02:06:44.0287+06	5	morning	{"(36,\\"2024-01-31 02:24:22.106+06\\")","(37,\\"2024-01-31 02:25:56.057+06\\")","(38,\\"2024-01-31 02:26:57.571+06\\")","(39,\\"2024-01-31 02:28:00.589+06\\")","(40,\\"2024-01-31 02:29:33.261+06\\")","(70,\\"2024-01-31 02:32:09.752+06\\")"}	to_buet	Ba-77-7044	t	rashed3	\N	2024-01-31 02:32:26.830395+06	(23.7660883,90.364925)	(23.7275268,90.3917003)	{"(23.7649583,90.36534)","(23.7642127,90.3653061)","(23.763966,90.3644196)","(23.7635667,90.3629833)","(23.7631566,90.3616)","(23.7626922,90.3599427)","(23.7619673,90.3588807)","(23.7606257,90.3588821)","(23.7594134,90.3591298)","(23.7582786,90.3597956)","(23.757416,90.3606085)","(23.7567556,90.3619079)","(23.7553636,90.3635747)","(23.7540429,90.3651788)","(23.7528579,90.3665731)","(23.751739,90.3676538)","(23.7506441,90.3684183)","(23.7496062,90.3691326)","(23.7485527,90.3698621)","(23.7475619,90.3705334)","(23.7464753,90.3712699)","(23.7454449,90.3719636)","(23.7445081,90.3725616)","(23.7434362,90.3732948)","(23.7424289,90.3739508)","(23.7414579,90.374452)","(23.7402636,90.375049)","(23.7391591,90.3756102)","(23.7382941,90.3762665)","(23.738683,90.3756855)","(23.7395038,90.3753022)","(23.7384414,90.3760868)","(23.7385189,90.3774315)","(23.7388197,90.3793567)","(23.7398813,90.3807054)","(23.7404818,90.3823661)","(23.7397015,90.383306)","(23.738315,90.3836105)","(23.7366835,90.3840001)","(23.7351339,90.38438)","(23.7333583,90.3848333)","(23.7324607,90.3857894)","(23.7321584,90.3870136)","(23.72971,90.38755)","(23.7277783,90.38928)","(23.7277284,90.3907508)","(23.7276,90.3917054)"}	f	0	reyazul
1930	2024-01-31 15:14:10.296909+06	4	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-83-8014	t	rafiqul	\N	2024-01-31 15:30:54.236178+06	(23.7267071,90.3880359)	(23.7267111,90.3881077)	{"(23.7267133,90.3880396)"}	f	0	mahmud64
1924	2024-01-31 16:58:29.913838+06	2	morning	{NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-22-4326	t	rafiqul	\N	2024-01-31 16:59:59.175579+06	(23.7481383,90.3800983)	(23.7407144,90.3830852)	{"(23.747948333333333,90.38021)","(23.74714,90.38071)","(23.746336666666668,90.381165)","(23.745058333333333,90.381905)","(23.743881666666667,90.38228333333333)","(23.74266,90.38259)","(23.741388333333333,90.38290666666667)"}	f	0	jamal7898
1931	2024-01-31 17:11:19.993161+06	4	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-01-31 17:12:07.136+06\\")"}	from_buet	Ba-83-8014	t	rafiqul	\N	2024-01-31 18:17:20.504623+06	(23.7272617,90.3894852)	(23.7648684,90.362928)	{"(23.72742424,90.38952306)","(23.72723315,90.39084778)","(23.72747979,90.38972707)","(23.72839502,90.38905589)","(23.72916022,90.38816033)","(23.73006908,90.38765401)","(23.73106458,90.38708456)","(23.73211297,90.38693844)","(23.73249312,90.385646)","(23.7333372,90.38489895)","(23.73433357,90.38466604)","(23.73523457,90.38425773)","(23.73648617,90.38403921)","(23.73740914,90.38378537)","(23.73833805,90.383601)","(23.73927028,90.38336656)","(23.73933127,90.38230218)","(23.73923418,90.3812476)","(23.73898232,90.38030386)","(23.73867508,90.37932409)","(23.73852853,90.37829491)","(23.73842503,90.37716909)","(23.73863024,90.37590965)","(23.73962306,90.37550073)","(23.74075863,90.37480071)","(23.74194087,90.37422286)","(23.74288106,90.37367614)","(23.74389185,90.37306376)","(23.74489102,90.37226392)","(23.74580263,90.37164569)","(23.74726573,90.3705733)","(23.74833498,90.36976167)","(23.7496622,90.36912699)","(23.75073574,90.36829627)","(23.75153495,90.36777138)","(23.75268138,90.36688452)","(23.75353426,90.36601961)","(23.75420882,90.36514768)","(23.75499203,90.3641664)","(23.75595636,90.36437693)","(23.7568904,90.36415729)","(23.75786953,90.36380382)","(23.75873282,90.36409829)","(23.75962336,90.36386946)","(23.76049656,90.36351761)","(23.76140771,90.36332804)","(23.76227281,90.36301732)","(23.76314569,90.36273093)","(23.76394367,90.36323979)","(23.76479898,90.36290691)"}	f	0	mahmud64
1100	2024-01-28 00:31:14.828099+06	3	evening	{"(17,\\"2024-02-17 23:30:00+06\\")","(18,\\"2024-02-17 23:45:00+06\\")","(19,\\"2024-02-17 23:48:00+06\\")","(20,\\"2024-02-17 23:50:00+06\\")","(21,\\"2024-02-17 23:52:00+06\\")","(22,\\"2024-02-17 23:54:00+06\\")","(23,\\"2024-02-17 23:56:00+06\\")","(24,\\"2024-02-17 23:58:00+06\\")","(25,\\"2024-02-17 00:00:00+06\\")","(26,\\"2024-02-17 00:02:00+06\\")","(70,\\"2024-02-17 00:04:00+06\\")"}	from_buet	Ba-35-1461	t	altaf	nazmul	2024-01-28 00:39:09.230239+06	(23.7623975,90.3646323)	(23.7383,90.44334)	{"(23.7623975,90.3646323)","(23.76468,90.36243)","(23.7645131,90.3634149)","(23.7638266,90.3641521)","(23.7623776,90.3646494)","(23.7613292,90.3649807)","(23.7598456,90.3655453)","(23.7590193,90.3649792)","(23.7582967,90.3635545)","(23.7571787,90.3637788)","(23.7560394,90.3641541)","(23.7542027,90.3649945)","(23.7531364,90.3662336)","(23.7519741,90.3674639)","(23.7505716,90.368466)","(23.749112,90.3694791)","(23.7477706,90.3703934)","(23.7463417,90.3713627)","(23.7450697,90.3722238)","(23.7436415,90.3731531)","(23.7419803,90.3741552)","(23.7406143,90.3748718)","(23.7390182,90.3756844)","(23.7384921,90.377086)","(23.7387387,90.378943)","(23.7390536,90.3805955)","(23.7401514,90.3807955)","(23.740429,90.3821749)","(23.740163,90.3832064)","(23.7389839,90.383449)","(23.7378089,90.3837567)","(23.7364706,90.3840403)","(23.735294,90.3843386)","(23.7340699,90.3846386)","(23.7329042,90.3849486)","(23.7324875,90.3859167)","(23.7325198,90.387099)","(23.7306868,90.3871348)","(23.7288259,90.3882462)","(23.727464,90.3896642)","(23.7277235,90.390747)","(23.727447,90.3917109)"}	t	0	rashid56
1132	2024-01-28 09:15:49.433306+06	6	afternoon	{"(41,\\"2024-01-28 19:40:00+06\\")","(42,\\"2024-01-28 19:56:00+06\\")","(43,\\"2024-01-28 19:58:00+06\\")","(44,\\"2024-01-28 20:00:00+06\\")","(45,\\"2024-01-28 20:02:00+06\\")","(46,\\"2024-01-28 20:04:00+06\\")","(47,\\"2024-01-28 20:06:00+06\\")","(48,\\"2024-01-28 20:08:00+06\\")","(49,\\"2024-01-28 20:10:00+06\\")","(70,\\"2024-01-28 20:12:00+06\\")"}	from_buet	Ba-17-2081	t	arif43	nazmul	2024-01-28 09:45:07.738489+06	(23.7266771,90.388158)	(23.7266784,90.3882818)	{"(23.72655019,90.38848189)","(23.72696112,90.38936913)","(23.72772774,90.39008871)","(23.72809878,90.39110518)","(23.72839477,90.39223458)","(23.72816985,90.39335134)","(23.72780276,90.39453776)","(23.7280286,90.39549392)","(23.72893826,90.39536566)","(23.72997105,90.39542245)","(23.73100256,90.39525183)","(23.73012462,90.39548402)","(23.7290751,90.39542807)","(23.72809697,90.39529247)","(23.72718984,90.39528533)","(23.7267802,90.39425865)","(23.72692749,90.39319299)","(23.72710812,90.39220914)","(23.72732432,90.39121605)","(23.72756128,90.39025052)","(23.72692572,90.3894264)"}	t	0	abdulbari4
\.


--
-- Name: feedback_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.feedback_id_seq', 48, true);


--
-- Name: purchase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.purchase_id_seq', 54, true);


--
-- Name: requisition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.requisition_id_seq', 33, true);


--
-- Name: student_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.student_notification_id_seq', 1, false);


--
-- Name: upcoming_trip_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.upcoming_trip_id_seq', 2019, true);


--
-- Name: admin admin_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admin
    ADD CONSTRAINT admin_pkey PRIMARY KEY (id);


--
-- Name: allocation allocation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_pkey PRIMARY KEY (id);


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
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (id);


--
-- Name: bus numplate; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.bus
    ADD CONSTRAINT numplate CHECK (((reg_id)::text ~ '^[A-Za-z]{2}-\d{2}-\d{4}$'::text)) NOT VALID;


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
-- Name: purchase purchase_trxid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase
    ADD CONSTRAINT purchase_trxid_key UNIQUE (trxid);


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
-- Name: session session_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session
    ADD CONSTRAINT session_pkey PRIMARY KEY (sid);


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
-- Name: IDX_session_expire; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "IDX_session_expire" ON public.session USING btree (expire);


--
-- Name: allocation allocation_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.admin(id) NOT VALID;


--
-- Name: allocation allocation_bus_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_bus_fkey FOREIGN KEY (bus) REFERENCES public.bus(reg_id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- Name: allocation allocation_driver_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_driver_fkey FOREIGN KEY (driver) REFERENCES public.bus_staff(id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- Name: allocation allocation_helper_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_helper_fkey FOREIGN KEY (helper) REFERENCES public.bus_staff(id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- Name: allocation allocation_route_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.allocation
    ADD CONSTRAINT allocation_route_fkey FOREIGN KEY (route) REFERENCES public.route(id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


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
    ADD CONSTRAINT schedule_route_fkey FOREIGN KEY (route) REFERENCES public.route(id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- Name: student student_default_route_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student
    ADD CONSTRAINT student_default_route_fkey FOREIGN KEY (default_route) REFERENCES public.route(id) NOT VALID;


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
    ADD CONSTRAINT trip_bus_fkey FOREIGN KEY (bus) REFERENCES public.bus(reg_id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- Name: trip trip_driver_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip
    ADD CONSTRAINT trip_driver_fkey FOREIGN KEY (driver) REFERENCES public.bus_staff(id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- Name: trip trip_helper_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip
    ADD CONSTRAINT trip_helper_fkey FOREIGN KEY (helper) REFERENCES public.bus_staff(id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- Name: trip trip_route_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip
    ADD CONSTRAINT trip_route_fkey FOREIGN KEY (route) REFERENCES public.route(id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- PostgreSQL database dump complete
--

