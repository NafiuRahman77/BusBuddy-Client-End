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
    'single_decker',
    'car',
    'micro-8',
    'micro-12',
    'micro-15'
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

CREATE PROCEDURE public.initiate_trip2(IN id_to_move bigint, IN bus_staff_id character varying, IN start_loc point)
    LANGUAGE plpgsql
    AS $$

  -- Declare variables to store record data
  DECLARE
    record_data record;

  -- Fetch the record from table1
  
BEGIN
  SELECT * INTO record_data FROM allocation WHERE id = id_to_move;
    IF record_data.driver = bus_staff_id OR record_data.helper = bus_staff_id THEN
        INSERT INTO trip( id,start_timestamp,route,time_type,time_list,travel_direction,bus,is_default,driver,approved_by,is_live,helper,start_location)  -- Specify column names
            VALUES (record_data.id,CURRENT_TIMESTAMP,record_data.route,record_data.time_type,record_data.time_list,record_data.travel_direction,record_data.bus,record_data.is_default,record_data.driver,record_data.approved_by,TRUE,record_data.helper,start_loc);
		  -- Delete the record from table1
  		DELETE FROM allocation WHERE id = id_to_move;
    ELSE
        RAISE NOTICE 'driver id does not match';
    END IF;
  -- Insert the fetched record into table2
  

  
  -- Commit the transaction
--   COMMIT;
END;

$$;


ALTER PROCEDURE public.initiate_trip2(IN id_to_move bigint, IN bus_staff_id character varying, IN start_loc point) OWNER TO postgres;

--
-- Name: make_purchase(character varying, public.payment_method, character varying, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.make_purchase(IN stu_id character varying, IN p_method public.payment_method, IN trx_id character varying, IN cnt integer)
    LANGUAGE plpgsql
    AS $$
	DECLARE
		purchase_id bigint;
		c_count integer;
	BEGIN
		SELECT COUNT(*) INTO c_count FROM ticket WHERE student_id = stu_id AND is_used = false;
		IF (cnt + c_count > 600) THEN
			RAISE NOTICE 'max_quota_exceeded';
		ELSE 
			INSERT INTO purchase(buyer_id, timestamp, payment_method, trxid, quantity) 
			VALUES (stu_id, current_timestamp, p_method, trx_id, cnt) RETURNING id INTO purchase_id;

			for i in 1..cnt LOOP
				INSERT INTO ticket(student_id, trip_id, purchase_id, is_used)
				VALUES (stu_id, null, purchase_id, false);
			END LOOP;
		END IF;
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
    helper character varying,
    valid boolean DEFAULT true NOT NULL
);


ALTER TABLE public.allocation OWNER TO postgres;

--
-- Name: assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assignment (
    id character varying NOT NULL,
    route character varying NOT NULL,
    bus character varying NOT NULL,
    driver character varying,
    helper character varying,
    valid boolean DEFAULT true NOT NULL
);


ALTER TABLE public.assignment OWNER TO postgres;

--
-- Name: broadcast_notification; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.broadcast_notification (
    id bigint NOT NULL,
    text text NOT NULL,
    "timestamp" timestamp with time zone NOT NULL
);


ALTER TABLE public.broadcast_notification OWNER TO postgres;

--
-- Name: broadcast_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.broadcast_notification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.broadcast_notification_id_seq OWNER TO postgres;

--
-- Name: broadcast_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.broadcast_notification_id_seq OWNED BY public.broadcast_notification.id;


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
    phone character(11),
    valid boolean DEFAULT true NOT NULL
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
    response text,
    valid boolean DEFAULT true NOT NULL
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
    response text,
    valid boolean DEFAULT true NOT NULL
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
    valid boolean DEFAULT true NOT NULL,
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
    valid boolean DEFAULT true NOT NULL,
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
    rate double precision,
    valid boolean DEFAULT true NOT NULL
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
    bus_type public.bus_type[],
    valid boolean DEFAULT true NOT NULL
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
    points character varying(32)[],
    valid boolean DEFAULT true NOT NULL,
    predefined_path point[]
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
    adjacent_points character varying(32)[],
    valid boolean DEFAULT true NOT NULL
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
    valid boolean DEFAULT true NOT NULL,
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
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    scanned_by character varying(32)
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
    helper character varying,
    valid boolean DEFAULT true NOT NULL
);


ALTER TABLE public.trip OWNER TO postgres;

--
-- Name: allocation id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.allocation ALTER COLUMN id SET DEFAULT nextval('public.upcoming_trip_id_seq'::regclass);


--
-- Name: broadcast_notification id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.broadcast_notification ALTER COLUMN id SET DEFAULT nextval('public.broadcast_notification_id_seq'::regclass);


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
reyazul	$2b$10$9lE1DV9rpWP0imXFkiQ8e.aYI3qbgmgYgqle1CAK4/qHSCgRwhZES	kazireyazulhasan@gmail.com	https://i.postimg.cc/wvrLNPxH/dp1.png
mashroor	$2b$10$XnTGAGmugMzJzioMGeUfJePP9SZe0drry4IA1jT9FjMuqYWp7gFYG	mashroor184@gmail.com	https://i.postimg.cc/tJn10N0z/IMG-20221028-093424.jpg
mubasshira	$2b$10$RSQg2f7AJ5k2kBnjz9eMuOPxlaYxmX/454dvj6kuToFWD1JClHIo6	mubasshira31@gmail.com	https://i.postimg.cc/3wknczS4/mubash.png
nazmul	$2b$10$T0O9n9D7jIwCLKSpdHc6WOaMGbOBurKUt2upKKlDFIY.FT082OpVy	\N	\N
\.


--
-- Data for Name: allocation; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.allocation (id, start_timestamp, route, time_type, time_list, travel_direction, bus, is_default, driver, approved_by, is_done, helper, valid) FROM stdin;
1925	2024-01-30 19:40:00+06	2	afternoon	{"(12,\\"2024-01-30 19:40:00+06\\")","(13,\\"2024-01-30 19:52:00+06\\")","(14,\\"2024-01-30 19:54:00+06\\")","(15,\\"2024-01-30 19:57:00+06\\")","(16,\\"2024-01-30 20:00:00+06\\")","(70,\\"2024-01-30 20:03:00+06\\")"}	from_buet	Ba-22-4326	t	arif43	\N	f	jamal7898	t
1926	2024-01-30 23:30:00+06	2	evening	{"(12,\\"2024-01-30 23:30:00+06\\")","(13,\\"2024-01-30 23:42:00+06\\")","(14,\\"2024-01-30 23:45:00+06\\")","(15,\\"2024-01-30 23:48:00+06\\")","(16,\\"2024-01-30 23:51:00+06\\")","(70,\\"2024-01-30 23:54:00+06\\")"}	from_buet	Ba-22-4326	t	arif43	\N	f	jamal7898	t
1927	2024-01-30 12:40:00+06	3	morning	{"(17,\\"2024-01-30 12:40:00+06\\")","(18,\\"2024-01-30 12:42:00+06\\")","(19,\\"2024-01-30 12:44:00+06\\")","(20,\\"2024-01-30 12:46:00+06\\")","(21,\\"2024-01-30 12:48:00+06\\")","(22,\\"2024-01-30 12:50:00+06\\")","(23,\\"2024-01-30 12:52:00+06\\")","(24,\\"2024-01-30 12:54:00+06\\")","(25,\\"2024-01-30 12:57:00+06\\")","(26,\\"2024-01-30 13:00:00+06\\")","(70,\\"2024-01-30 13:15:00+06\\")"}	to_buet	Ba-97-6734	t	altaf78	\N	f	abdulbari4	t
1928	2024-01-30 19:40:00+06	3	afternoon	{"(17,\\"2024-01-30 19:40:00+06\\")","(18,\\"2024-01-30 19:55:00+06\\")","(19,\\"2024-01-30 19:58:00+06\\")","(20,\\"2024-01-30 20:00:00+06\\")","(21,\\"2024-01-30 20:02:00+06\\")","(22,\\"2024-01-30 20:04:00+06\\")","(23,\\"2024-01-30 20:06:00+06\\")","(24,\\"2024-01-30 20:08:00+06\\")","(25,\\"2024-01-30 20:10:00+06\\")","(26,\\"2024-01-30 20:12:00+06\\")","(70,\\"2024-01-30 20:14:00+06\\")"}	from_buet	Ba-97-6734	t	altaf78	\N	f	abdulbari4	t
1929	2024-01-30 23:30:00+06	3	evening	{"(17,\\"2024-01-30 23:30:00+06\\")","(18,\\"2024-01-30 23:45:00+06\\")","(19,\\"2024-01-30 23:48:00+06\\")","(20,\\"2024-01-30 23:50:00+06\\")","(21,\\"2024-01-30 23:52:00+06\\")","(22,\\"2024-01-30 23:54:00+06\\")","(23,\\"2024-01-30 23:56:00+06\\")","(24,\\"2024-01-30 23:58:00+06\\")","(25,\\"2024-01-30 00:00:00+06\\")","(26,\\"2024-01-30 00:02:00+06\\")","(70,\\"2024-01-30 00:04:00+06\\")"}	from_buet	Ba-97-6734	t	altaf78	\N	f	abdulbari4	t
1936	2024-01-30 12:40:00+06	6	morning	{"(41,\\"2024-01-30 12:40:00+06\\")","(42,\\"2024-01-30 12:42:00+06\\")","(43,\\"2024-01-30 12:45:00+06\\")","(44,\\"2024-01-30 12:47:00+06\\")","(45,\\"2024-01-30 12:49:00+06\\")","(46,\\"2024-01-30 12:51:00+06\\")","(47,\\"2024-01-30 12:52:00+06\\")","(48,\\"2024-01-30 12:53:00+06\\")","(49,\\"2024-01-30 12:54:00+06\\")","(70,\\"2024-01-30 13:10:00+06\\")"}	to_buet	Ba-48-5757	t	shahid88	\N	f	alamgir	t
1937	2024-01-30 19:40:00+06	6	afternoon	{"(41,\\"2024-01-30 19:40:00+06\\")","(42,\\"2024-01-30 19:56:00+06\\")","(43,\\"2024-01-30 19:58:00+06\\")","(44,\\"2024-01-30 20:00:00+06\\")","(45,\\"2024-01-30 20:02:00+06\\")","(46,\\"2024-01-30 20:04:00+06\\")","(47,\\"2024-01-30 20:06:00+06\\")","(48,\\"2024-01-30 20:08:00+06\\")","(49,\\"2024-01-30 20:10:00+06\\")","(70,\\"2024-01-30 20:12:00+06\\")"}	from_buet	Ba-48-5757	t	shahid88	\N	f	alamgir	t
1938	2024-01-30 23:30:00+06	6	evening	{"(41,\\"2024-01-30 23:30:00+06\\")","(42,\\"2024-01-30 23:46:00+06\\")","(43,\\"2024-01-30 23:48:00+06\\")","(44,\\"2024-01-30 23:50:00+06\\")","(45,\\"2024-01-30 23:52:00+06\\")","(46,\\"2024-01-30 23:54:00+06\\")","(47,\\"2024-01-30 23:56:00+06\\")","(48,\\"2024-01-30 23:58:00+06\\")","(49,\\"2024-01-30 00:00:00+06\\")","(70,\\"2024-01-30 00:02:00+06\\")"}	from_buet	Ba-48-5757	t	shahid88	\N	f	alamgir	t
1970	2024-02-01 19:40:00+06	8	afternoon	{"(64,\\"2024-02-01 19:40:00+06\\")","(65,\\"2024-02-01 19:55:00+06\\")","(66,\\"2024-02-01 19:58:00+06\\")","(67,\\"2024-02-01 20:01:00+06\\")","(68,\\"2024-02-01 20:04:00+06\\")","(69,\\"2024-02-01 20:07:00+06\\")","(70,\\"2024-02-01 20:10:00+06\\")"}	from_buet	Ba-36-1921	t	nizam88	nazmul	f	azim990	t
1971	2024-02-01 23:30:00+06	8	evening	{"(64,\\"2024-02-01 23:30:00+06\\")","(65,\\"2024-02-01 23:45:00+06\\")","(66,\\"2024-02-01 23:48:00+06\\")","(67,\\"2024-02-01 23:51:00+06\\")","(68,\\"2024-02-01 23:54:00+06\\")","(69,\\"2024-02-01 23:57:00+06\\")","(70,\\"2024-02-01 00:00:00+06\\")"}	from_buet	Ba-36-1921	t	nizam88	nazmul	f	mahbub777	t
2175	2024-02-10 23:30:00+06	5	evening	{"(36,\\"2024-02-10 23:30:00+06\\")","(37,\\"2024-02-10 23:40:00+06\\")","(38,\\"2024-02-10 23:45:00+06\\")","(39,\\"2024-02-10 23:50:00+06\\")","(40,\\"2024-02-10 23:57:00+06\\")","(70,\\"2024-02-10 00:00:00+06\\")"}	from_buet	Ba-22-4326	t	fazlu77	nazmul	f	rashid56	t
1942	2024-01-30 12:15:00+06	1	morning	{"(1,\\"2024-01-30 12:15:00+06\\")","(2,\\"2024-01-30 12:18:00+06\\")","(3,\\"2024-01-30 12:20:00+06\\")","(4,\\"2024-01-30 12:23:00+06\\")","(5,\\"2024-01-30 12:26:00+06\\")","(6,\\"2024-01-30 12:29:00+06\\")","(7,\\"2024-01-30 12:49:00+06\\")","(8,\\"2024-01-30 12:51:00+06\\")","(9,\\"2024-01-30 12:53:00+06\\")","(10,\\"2024-01-30 12:55:00+06\\")","(11,\\"2024-01-30 12:58:00+06\\")","(70,\\"2024-01-30 13:05:00+06\\")"}	to_buet	Ba-93-6087	t	abdulkarim6	\N	f	zahir53	t
1943	2024-01-30 19:40:00+06	1	afternoon	{"(1,\\"2024-01-30 19:40:00+06\\")","(2,\\"2024-01-30 19:47:00+06\\")","(3,\\"2024-01-30 19:50:00+06\\")","(4,\\"2024-01-30 19:52:00+06\\")","(5,\\"2024-01-30 19:54:00+06\\")","(6,\\"2024-01-30 20:06:00+06\\")","(7,\\"2024-01-30 20:09:00+06\\")","(8,\\"2024-01-30 20:12:00+06\\")","(9,\\"2024-01-30 20:15:00+06\\")","(10,\\"2024-01-30 20:18:00+06\\")","(11,\\"2024-01-30 20:21:00+06\\")","(70,\\"2024-01-30 20:24:00+06\\")"}	from_buet	Ba-93-6087	t	abdulkarim6	\N	f	zahir53	t
1944	2024-01-30 23:30:00+06	1	evening	{"(1,\\"2024-01-30 23:30:00+06\\")","(2,\\"2024-01-30 23:37:00+06\\")","(3,\\"2024-01-30 23:40:00+06\\")","(4,\\"2024-01-30 23:42:00+06\\")","(5,\\"2024-01-30 23:44:00+06\\")","(6,\\"2024-01-30 23:56:00+06\\")","(7,\\"2024-01-30 23:59:00+06\\")","(8,\\"2024-01-30 00:02:00+06\\")","(9,\\"2024-01-30 00:05:00+06\\")","(10,\\"2024-01-30 00:08:00+06\\")","(11,\\"2024-01-30 00:11:00+06\\")","(70,\\"2024-01-30 00:14:00+06\\")"}	from_buet	Ba-93-6087	t	abdulkarim6	\N	f	zahir53	t
1945	2024-01-30 12:10:00+06	8	morning	{"(64,\\"2024-01-30 12:10:00+06\\")","(65,\\"2024-01-30 12:13:00+06\\")","(66,\\"2024-01-30 12:18:00+06\\")","(67,\\"2024-01-30 12:20:00+06\\")","(68,\\"2024-01-30 12:22:00+06\\")","(69,\\"2024-01-30 12:25:00+06\\")","(70,\\"2024-01-30 12:40:00+06\\")"}	to_buet	Ba-34-7413	t	shafiqul	\N	f	azim990	t
1946	2024-01-30 19:40:00+06	8	afternoon	{"(64,\\"2024-01-30 19:40:00+06\\")","(65,\\"2024-01-30 19:55:00+06\\")","(66,\\"2024-01-30 19:58:00+06\\")","(67,\\"2024-01-30 20:01:00+06\\")","(68,\\"2024-01-30 20:04:00+06\\")","(69,\\"2024-01-30 20:07:00+06\\")","(70,\\"2024-01-30 20:10:00+06\\")"}	from_buet	Ba-34-7413	t	shafiqul	\N	f	azim990	t
1947	2024-01-30 23:30:00+06	8	evening	{"(64,\\"2024-01-30 23:30:00+06\\")","(65,\\"2024-01-30 23:45:00+06\\")","(66,\\"2024-01-30 23:48:00+06\\")","(67,\\"2024-01-30 23:51:00+06\\")","(68,\\"2024-01-30 23:54:00+06\\")","(69,\\"2024-01-30 23:57:00+06\\")","(70,\\"2024-01-30 00:00:00+06\\")"}	from_buet	Ba-34-7413	t	shafiqul	\N	f	azim990	t
1948	2024-02-01 12:55:00+06	2	morning	{"(12,\\"2024-02-01 12:55:00+06\\")","(13,\\"2024-02-01 12:57:00+06\\")","(14,\\"2024-02-01 12:59:00+06\\")","(15,\\"2024-02-01 13:01:00+06\\")","(16,\\"2024-02-01 13:03:00+06\\")","(70,\\"2024-02-01 13:15:00+06\\")"}	to_buet	Ba-43-4286	t	monu67	nazmul	f	mahbub777	t
1949	2024-02-01 19:40:00+06	2	afternoon	{"(12,\\"2024-02-01 19:40:00+06\\")","(13,\\"2024-02-01 19:52:00+06\\")","(14,\\"2024-02-01 19:54:00+06\\")","(15,\\"2024-02-01 19:57:00+06\\")","(16,\\"2024-02-01 20:00:00+06\\")","(70,\\"2024-02-01 20:03:00+06\\")"}	from_buet	Ba-43-4286	t	monu67	nazmul	f	mahbub777	t
1950	2024-02-01 23:30:00+06	2	evening	{"(12,\\"2024-02-01 23:30:00+06\\")","(13,\\"2024-02-01 23:42:00+06\\")","(14,\\"2024-02-01 23:45:00+06\\")","(15,\\"2024-02-01 23:48:00+06\\")","(16,\\"2024-02-01 23:51:00+06\\")","(70,\\"2024-02-01 23:54:00+06\\")"}	from_buet	Ba-43-4286	t	monu67	nazmul	f	mahbub777	t
1951	2024-02-01 12:40:00+06	3	morning	{"(17,\\"2024-02-01 12:40:00+06\\")","(18,\\"2024-02-01 12:42:00+06\\")","(19,\\"2024-02-01 12:44:00+06\\")","(20,\\"2024-02-01 12:46:00+06\\")","(21,\\"2024-02-01 12:48:00+06\\")","(22,\\"2024-02-01 12:50:00+06\\")","(23,\\"2024-02-01 12:52:00+06\\")","(24,\\"2024-02-01 12:54:00+06\\")","(25,\\"2024-02-01 12:57:00+06\\")","(26,\\"2024-02-01 13:00:00+06\\")","(70,\\"2024-02-01 13:15:00+06\\")"}	to_buet	Ba-24-8518	t	sohel55	nazmul	f	alamgir	t
1952	2024-02-01 19:40:00+06	3	afternoon	{"(17,\\"2024-02-01 19:40:00+06\\")","(18,\\"2024-02-01 19:55:00+06\\")","(19,\\"2024-02-01 19:58:00+06\\")","(20,\\"2024-02-01 20:00:00+06\\")","(21,\\"2024-02-01 20:02:00+06\\")","(22,\\"2024-02-01 20:04:00+06\\")","(23,\\"2024-02-01 20:06:00+06\\")","(24,\\"2024-02-01 20:08:00+06\\")","(25,\\"2024-02-01 20:10:00+06\\")","(26,\\"2024-02-01 20:12:00+06\\")","(70,\\"2024-02-01 20:14:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	f	alamgir	t
1953	2024-02-01 23:30:00+06	3	evening	{"(17,\\"2024-02-01 23:30:00+06\\")","(18,\\"2024-02-01 23:45:00+06\\")","(19,\\"2024-02-01 23:48:00+06\\")","(20,\\"2024-02-01 23:50:00+06\\")","(21,\\"2024-02-01 23:52:00+06\\")","(22,\\"2024-02-01 23:54:00+06\\")","(23,\\"2024-02-01 23:56:00+06\\")","(24,\\"2024-02-01 23:58:00+06\\")","(25,\\"2024-02-01 00:00:00+06\\")","(26,\\"2024-02-01 00:02:00+06\\")","(70,\\"2024-02-01 00:04:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	f	alamgir	t
1954	2024-02-01 12:40:00+06	4	morning	{"(27,\\"2024-02-01 12:40:00+06\\")","(28,\\"2024-02-01 12:42:00+06\\")","(29,\\"2024-02-01 12:44:00+06\\")","(30,\\"2024-02-01 12:46:00+06\\")","(31,\\"2024-02-01 12:50:00+06\\")","(32,\\"2024-02-01 12:52:00+06\\")","(33,\\"2024-02-01 12:54:00+06\\")","(34,\\"2024-02-01 12:58:00+06\\")","(35,\\"2024-02-01 13:00:00+06\\")","(70,\\"2024-02-01 13:10:00+06\\")"}	to_buet	Ba-35-1461	t	altaf78	nazmul	f	mahabhu	t
1972	2024-02-05 12:55:00+06	2	morning	{"(12,\\"2024-02-05 12:55:00+06\\")","(13,\\"2024-02-05 12:57:00+06\\")","(14,\\"2024-02-05 12:59:00+06\\")","(15,\\"2024-02-05 13:01:00+06\\")","(16,\\"2024-02-05 13:03:00+06\\")","(70,\\"2024-02-05 13:15:00+06\\")"}	to_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81	t
1973	2024-02-05 19:40:00+06	2	afternoon	{"(12,\\"2024-02-05 19:40:00+06\\")","(13,\\"2024-02-05 19:52:00+06\\")","(14,\\"2024-02-05 19:54:00+06\\")","(15,\\"2024-02-05 19:57:00+06\\")","(16,\\"2024-02-05 20:00:00+06\\")","(70,\\"2024-02-05 20:03:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81	t
1974	2024-02-05 23:30:00+06	2	evening	{"(12,\\"2024-02-05 23:30:00+06\\")","(13,\\"2024-02-05 23:42:00+06\\")","(14,\\"2024-02-05 23:45:00+06\\")","(15,\\"2024-02-05 23:48:00+06\\")","(16,\\"2024-02-05 23:51:00+06\\")","(70,\\"2024-02-05 23:54:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81	t
1975	2024-02-05 12:40:00+06	3	morning	{"(17,\\"2024-02-05 12:40:00+06\\")","(18,\\"2024-02-05 12:42:00+06\\")","(19,\\"2024-02-05 12:44:00+06\\")","(20,\\"2024-02-05 12:46:00+06\\")","(21,\\"2024-02-05 12:48:00+06\\")","(22,\\"2024-02-05 12:50:00+06\\")","(23,\\"2024-02-05 12:52:00+06\\")","(24,\\"2024-02-05 12:54:00+06\\")","(25,\\"2024-02-05 12:57:00+06\\")","(26,\\"2024-02-05 13:00:00+06\\")","(70,\\"2024-02-05 13:15:00+06\\")"}	to_buet	Ba-69-8288	t	jahangir	nazmul	f	ASADUZZAMAN	t
1955	2024-02-01 19:40:00+06	4	afternoon	{"(27,\\"2024-02-01 19:40:00+06\\")","(28,\\"2024-02-01 19:50:00+06\\")","(29,\\"2024-02-01 19:52:00+06\\")","(30,\\"2024-02-01 19:54:00+06\\")","(31,\\"2024-02-01 19:56:00+06\\")","(32,\\"2024-02-01 19:58:00+06\\")","(33,\\"2024-02-01 20:00:00+06\\")","(34,\\"2024-02-01 20:02:00+06\\")","(35,\\"2024-02-01 20:04:00+06\\")","(70,\\"2024-02-01 20:06:00+06\\")"}	from_buet	Ba-35-1461	t	altaf78	nazmul	f	mahabhu	t
1956	2024-02-01 23:30:00+06	4	evening	{"(27,\\"2024-02-01 23:30:00+06\\")","(28,\\"2024-02-01 23:40:00+06\\")","(29,\\"2024-02-01 23:42:00+06\\")","(30,\\"2024-02-01 23:44:00+06\\")","(31,\\"2024-02-01 23:46:00+06\\")","(32,\\"2024-02-01 23:48:00+06\\")","(33,\\"2024-02-01 23:50:00+06\\")","(34,\\"2024-02-01 23:52:00+06\\")","(35,\\"2024-02-01 23:54:00+06\\")","(70,\\"2024-02-01 23:56:00+06\\")"}	from_buet	Ba-35-1461	t	altaf78	nazmul	f	mahabhu	t
1960	2024-02-01 12:40:00+06	6	morning	{"(41,\\"2024-02-01 12:40:00+06\\")","(42,\\"2024-02-01 12:42:00+06\\")","(43,\\"2024-02-01 12:45:00+06\\")","(44,\\"2024-02-01 12:47:00+06\\")","(45,\\"2024-02-01 12:49:00+06\\")","(46,\\"2024-02-01 12:51:00+06\\")","(47,\\"2024-02-01 12:52:00+06\\")","(48,\\"2024-02-01 12:53:00+06\\")","(49,\\"2024-02-01 12:54:00+06\\")","(70,\\"2024-02-01 13:10:00+06\\")"}	to_buet	Ba-63-1146	t	polash	nazmul	f	nasir81	t
1961	2024-02-01 19:40:00+06	6	afternoon	{"(41,\\"2024-02-01 19:40:00+06\\")","(42,\\"2024-02-01 19:56:00+06\\")","(43,\\"2024-02-01 19:58:00+06\\")","(44,\\"2024-02-01 20:00:00+06\\")","(45,\\"2024-02-01 20:02:00+06\\")","(46,\\"2024-02-01 20:04:00+06\\")","(47,\\"2024-02-01 20:06:00+06\\")","(48,\\"2024-02-01 20:08:00+06\\")","(49,\\"2024-02-01 20:10:00+06\\")","(70,\\"2024-02-01 20:12:00+06\\")"}	from_buet	Ba-63-1146	t	polash	nazmul	f	nasir81	t
1962	2024-02-01 23:30:00+06	6	evening	{"(41,\\"2024-02-01 23:30:00+06\\")","(42,\\"2024-02-01 23:46:00+06\\")","(43,\\"2024-02-01 23:48:00+06\\")","(44,\\"2024-02-01 23:50:00+06\\")","(45,\\"2024-02-01 23:52:00+06\\")","(46,\\"2024-02-01 23:54:00+06\\")","(47,\\"2024-02-01 23:56:00+06\\")","(48,\\"2024-02-01 23:58:00+06\\")","(49,\\"2024-02-01 00:00:00+06\\")","(70,\\"2024-02-01 00:02:00+06\\")"}	from_buet	Ba-63-1146	t	polash	nazmul	f	nasir81	t
1963	2024-02-01 12:40:00+06	7	morning	{"(50,\\"2024-02-01 12:40:00+06\\")","(51,\\"2024-02-01 12:42:00+06\\")","(52,\\"2024-02-01 12:43:00+06\\")","(53,\\"2024-02-01 12:46:00+06\\")","(54,\\"2024-02-01 12:47:00+06\\")","(55,\\"2024-02-01 12:48:00+06\\")","(56,\\"2024-02-01 12:50:00+06\\")","(57,\\"2024-02-01 12:52:00+06\\")","(58,\\"2024-02-01 12:53:00+06\\")","(59,\\"2024-02-01 12:54:00+06\\")","(60,\\"2024-02-01 12:56:00+06\\")","(61,\\"2024-02-01 12:58:00+06\\")","(62,\\"2024-02-01 13:00:00+06\\")","(63,\\"2024-02-01 13:02:00+06\\")","(70,\\"2024-02-01 13:00:00+06\\")"}	to_buet	Ba-83-8014	t	shahid88	nazmul	f	abdulbari4	t
1964	2024-02-01 19:40:00+06	7	afternoon	{"(50,\\"2024-02-01 19:40:00+06\\")","(51,\\"2024-02-01 19:48:00+06\\")","(52,\\"2024-02-01 19:50:00+06\\")","(53,\\"2024-02-01 19:52:00+06\\")","(54,\\"2024-02-01 19:54:00+06\\")","(55,\\"2024-02-01 19:56:00+06\\")","(56,\\"2024-02-01 19:58:00+06\\")","(57,\\"2024-02-01 20:00:00+06\\")","(58,\\"2024-02-01 20:02:00+06\\")","(59,\\"2024-02-01 20:04:00+06\\")","(60,\\"2024-02-01 20:06:00+06\\")","(61,\\"2024-02-01 20:08:00+06\\")","(62,\\"2024-02-01 20:10:00+06\\")","(63,\\"2024-02-01 20:12:00+06\\")","(70,\\"2024-02-01 20:14:00+06\\")"}	from_buet	Ba-83-8014	t	shahid88	nazmul	f	abdulbari4	t
1965	2024-02-01 23:30:00+06	7	evening	{"(50,\\"2024-02-01 23:30:00+06\\")","(51,\\"2024-02-01 23:38:00+06\\")","(52,\\"2024-02-01 23:40:00+06\\")","(53,\\"2024-02-01 23:42:00+06\\")","(54,\\"2024-02-01 23:44:00+06\\")","(55,\\"2024-02-01 23:46:00+06\\")","(56,\\"2024-02-01 23:48:00+06\\")","(57,\\"2024-02-01 23:50:00+06\\")","(58,\\"2024-02-01 23:52:00+06\\")","(59,\\"2024-02-01 23:54:00+06\\")","(60,\\"2024-02-01 23:56:00+06\\")","(61,\\"2024-02-01 23:58:00+06\\")","(62,\\"2024-02-01 00:00:00+06\\")","(63,\\"2024-02-01 00:02:00+06\\")","(70,\\"2024-02-01 00:04:00+06\\")"}	from_buet	Ba-83-8014	t	shahid88	nazmul	f	abdulbari4	t
1966	2024-02-01 12:15:00+06	1	morning	{"(1,\\"2024-02-01 12:15:00+06\\")","(2,\\"2024-02-01 12:18:00+06\\")","(3,\\"2024-02-01 12:20:00+06\\")","(4,\\"2024-02-01 12:23:00+06\\")","(5,\\"2024-02-01 12:26:00+06\\")","(6,\\"2024-02-01 12:29:00+06\\")","(7,\\"2024-02-01 12:49:00+06\\")","(8,\\"2024-02-01 12:51:00+06\\")","(9,\\"2024-02-01 12:53:00+06\\")","(10,\\"2024-02-01 12:55:00+06\\")","(11,\\"2024-02-01 12:58:00+06\\")","(70,\\"2024-02-01 13:05:00+06\\")"}	to_buet	Ba-98-5568	t	jahangir	nazmul	f	ASADUZZAMAN	t
1967	2024-02-01 19:40:00+06	1	afternoon	{"(1,\\"2024-02-01 19:40:00+06\\")","(2,\\"2024-02-01 19:47:00+06\\")","(3,\\"2024-02-01 19:50:00+06\\")","(4,\\"2024-02-01 19:52:00+06\\")","(5,\\"2024-02-01 19:54:00+06\\")","(6,\\"2024-02-01 20:06:00+06\\")","(7,\\"2024-02-01 20:09:00+06\\")","(8,\\"2024-02-01 20:12:00+06\\")","(9,\\"2024-02-01 20:15:00+06\\")","(10,\\"2024-02-01 20:18:00+06\\")","(11,\\"2024-02-01 20:21:00+06\\")","(70,\\"2024-02-01 20:24:00+06\\")"}	from_buet	Ba-98-5568	t	jahangir	nazmul	f	ASADUZZAMAN	t
1968	2024-02-01 23:30:00+06	1	evening	{"(1,\\"2024-02-01 23:30:00+06\\")","(2,\\"2024-02-01 23:37:00+06\\")","(3,\\"2024-02-01 23:40:00+06\\")","(4,\\"2024-02-01 23:42:00+06\\")","(5,\\"2024-02-01 23:44:00+06\\")","(6,\\"2024-02-01 23:56:00+06\\")","(7,\\"2024-02-01 23:59:00+06\\")","(8,\\"2024-02-01 00:02:00+06\\")","(9,\\"2024-02-01 00:05:00+06\\")","(10,\\"2024-02-01 00:08:00+06\\")","(11,\\"2024-02-01 00:11:00+06\\")","(70,\\"2024-02-01 00:14:00+06\\")"}	from_buet	Ba-98-5568	t	jahangir	nazmul	f	ASADUZZAMAN	t
1969	2024-02-01 12:10:00+06	8	morning	{"(64,\\"2024-02-01 12:10:00+06\\")","(65,\\"2024-02-01 12:13:00+06\\")","(66,\\"2024-02-01 12:18:00+06\\")","(67,\\"2024-02-01 12:20:00+06\\")","(68,\\"2024-02-01 12:22:00+06\\")","(69,\\"2024-02-01 12:25:00+06\\")","(70,\\"2024-02-01 12:40:00+06\\")"}	to_buet	Ba-36-1921	t	nizam88	nazmul	f	azim990	t
1976	2024-02-05 19:40:00+06	3	afternoon	{"(17,\\"2024-02-05 19:40:00+06\\")","(18,\\"2024-02-05 19:55:00+06\\")","(19,\\"2024-02-05 19:58:00+06\\")","(20,\\"2024-02-05 20:00:00+06\\")","(21,\\"2024-02-05 20:02:00+06\\")","(22,\\"2024-02-05 20:04:00+06\\")","(23,\\"2024-02-05 20:06:00+06\\")","(24,\\"2024-02-05 20:08:00+06\\")","(25,\\"2024-02-05 20:10:00+06\\")","(26,\\"2024-02-05 20:12:00+06\\")","(70,\\"2024-02-05 20:14:00+06\\")"}	from_buet	Ba-69-8288	t	jahangir	nazmul	f	ASADUZZAMAN	t
1977	2024-02-05 23:30:00+06	3	evening	{"(17,\\"2024-02-05 23:30:00+06\\")","(18,\\"2024-02-05 23:45:00+06\\")","(19,\\"2024-02-05 23:48:00+06\\")","(20,\\"2024-02-05 23:50:00+06\\")","(21,\\"2024-02-05 23:52:00+06\\")","(22,\\"2024-02-05 23:54:00+06\\")","(23,\\"2024-02-05 23:56:00+06\\")","(24,\\"2024-02-05 23:58:00+06\\")","(25,\\"2024-02-05 00:00:00+06\\")","(26,\\"2024-02-05 00:02:00+06\\")","(70,\\"2024-02-05 00:04:00+06\\")"}	from_buet	Ba-69-8288	t	jahangir	nazmul	f	ASADUZZAMAN	t
1978	2024-02-05 12:40:00+06	4	morning	{"(27,\\"2024-02-05 12:40:00+06\\")","(28,\\"2024-02-05 12:42:00+06\\")","(29,\\"2024-02-05 12:44:00+06\\")","(30,\\"2024-02-05 12:46:00+06\\")","(31,\\"2024-02-05 12:50:00+06\\")","(32,\\"2024-02-05 12:52:00+06\\")","(33,\\"2024-02-05 12:54:00+06\\")","(34,\\"2024-02-05 12:58:00+06\\")","(35,\\"2024-02-05 13:00:00+06\\")","(70,\\"2024-02-05 13:10:00+06\\")"}	to_buet	Ba-93-6087	t	rahmatullah	nazmul	f	shamsul54	t
1979	2024-02-05 19:40:00+06	4	afternoon	{"(27,\\"2024-02-05 19:40:00+06\\")","(28,\\"2024-02-05 19:50:00+06\\")","(29,\\"2024-02-05 19:52:00+06\\")","(30,\\"2024-02-05 19:54:00+06\\")","(31,\\"2024-02-05 19:56:00+06\\")","(32,\\"2024-02-05 19:58:00+06\\")","(33,\\"2024-02-05 20:00:00+06\\")","(34,\\"2024-02-05 20:02:00+06\\")","(35,\\"2024-02-05 20:04:00+06\\")","(70,\\"2024-02-05 20:06:00+06\\")"}	from_buet	Ba-93-6087	t	rahmatullah	nazmul	f	shamsul54	t
1980	2024-02-05 23:30:00+06	4	evening	{"(27,\\"2024-02-05 23:30:00+06\\")","(28,\\"2024-02-05 23:40:00+06\\")","(29,\\"2024-02-05 23:42:00+06\\")","(30,\\"2024-02-05 23:44:00+06\\")","(31,\\"2024-02-05 23:46:00+06\\")","(32,\\"2024-02-05 23:48:00+06\\")","(33,\\"2024-02-05 23:50:00+06\\")","(34,\\"2024-02-05 23:52:00+06\\")","(35,\\"2024-02-05 23:54:00+06\\")","(70,\\"2024-02-05 23:56:00+06\\")"}	from_buet	Ba-93-6087	t	rahmatullah	nazmul	f	shamsul54	t
1981	2024-02-05 12:30:00+06	5	morning	{"(36,\\"2024-02-05 12:30:00+06\\")","(37,\\"2024-02-05 12:33:00+06\\")","(38,\\"2024-02-05 12:40:00+06\\")","(39,\\"2024-02-05 12:45:00+06\\")","(40,\\"2024-02-05 12:50:00+06\\")","(70,\\"2024-02-05 13:00:00+06\\")"}	to_buet	Ba-17-2081	t	shafiqul	nazmul	f	mahabhu	t
1982	2024-02-05 19:40:00+06	5	afternoon	{"(36,\\"2024-02-05 19:40:00+06\\")","(37,\\"2024-02-05 19:50:00+06\\")","(38,\\"2024-02-05 19:55:00+06\\")","(39,\\"2024-02-05 20:00:00+06\\")","(40,\\"2024-02-05 20:07:00+06\\")","(70,\\"2024-02-05 20:10:00+06\\")"}	from_buet	Ba-17-2081	t	shafiqul	nazmul	f	mahabhu	t
1983	2024-02-05 23:30:00+06	5	evening	{"(36,\\"2024-02-05 23:30:00+06\\")","(37,\\"2024-02-05 23:40:00+06\\")","(38,\\"2024-02-05 23:45:00+06\\")","(39,\\"2024-02-05 23:50:00+06\\")","(40,\\"2024-02-05 23:57:00+06\\")","(70,\\"2024-02-05 00:00:00+06\\")"}	from_buet	Ba-17-2081	t	shafiqul	nazmul	f	mahabhu	t
1984	2024-02-05 12:40:00+06	6	morning	{"(41,\\"2024-02-05 12:40:00+06\\")","(42,\\"2024-02-05 12:42:00+06\\")","(43,\\"2024-02-05 12:45:00+06\\")","(44,\\"2024-02-05 12:47:00+06\\")","(45,\\"2024-02-05 12:49:00+06\\")","(46,\\"2024-02-05 12:51:00+06\\")","(47,\\"2024-02-05 12:52:00+06\\")","(48,\\"2024-02-05 12:53:00+06\\")","(49,\\"2024-02-05 12:54:00+06\\")","(70,\\"2024-02-05 13:10:00+06\\")"}	to_buet	Ba-12-8888	t	aminhaque	nazmul	f	alamgir	t
1985	2024-02-05 19:40:00+06	6	afternoon	{"(41,\\"2024-02-05 19:40:00+06\\")","(42,\\"2024-02-05 19:56:00+06\\")","(43,\\"2024-02-05 19:58:00+06\\")","(44,\\"2024-02-05 20:00:00+06\\")","(45,\\"2024-02-05 20:02:00+06\\")","(46,\\"2024-02-05 20:04:00+06\\")","(47,\\"2024-02-05 20:06:00+06\\")","(48,\\"2024-02-05 20:08:00+06\\")","(49,\\"2024-02-05 20:10:00+06\\")","(70,\\"2024-02-05 20:12:00+06\\")"}	from_buet	Ba-12-8888	t	aminhaque	nazmul	f	alamgir	t
1986	2024-02-05 23:30:00+06	6	evening	{"(41,\\"2024-02-05 23:30:00+06\\")","(42,\\"2024-02-05 23:46:00+06\\")","(43,\\"2024-02-05 23:48:00+06\\")","(44,\\"2024-02-05 23:50:00+06\\")","(45,\\"2024-02-05 23:52:00+06\\")","(46,\\"2024-02-05 23:54:00+06\\")","(47,\\"2024-02-05 23:56:00+06\\")","(48,\\"2024-02-05 23:58:00+06\\")","(49,\\"2024-02-05 00:00:00+06\\")","(70,\\"2024-02-05 00:02:00+06\\")"}	from_buet	Ba-12-8888	t	aminhaque	nazmul	f	alamgir	t
1987	2024-02-05 12:40:00+06	7	morning	{"(50,\\"2024-02-05 12:40:00+06\\")","(51,\\"2024-02-05 12:42:00+06\\")","(52,\\"2024-02-05 12:43:00+06\\")","(53,\\"2024-02-05 12:46:00+06\\")","(54,\\"2024-02-05 12:47:00+06\\")","(55,\\"2024-02-05 12:48:00+06\\")","(56,\\"2024-02-05 12:50:00+06\\")","(57,\\"2024-02-05 12:52:00+06\\")","(58,\\"2024-02-05 12:53:00+06\\")","(59,\\"2024-02-05 12:54:00+06\\")","(60,\\"2024-02-05 12:56:00+06\\")","(61,\\"2024-02-05 12:58:00+06\\")","(62,\\"2024-02-05 13:00:00+06\\")","(63,\\"2024-02-05 13:02:00+06\\")","(70,\\"2024-02-05 13:00:00+06\\")"}	to_buet	Ba-98-5568	t	polash	nazmul	f	mahmud64	t
1988	2024-02-05 19:40:00+06	7	afternoon	{"(50,\\"2024-02-05 19:40:00+06\\")","(51,\\"2024-02-05 19:48:00+06\\")","(52,\\"2024-02-05 19:50:00+06\\")","(53,\\"2024-02-05 19:52:00+06\\")","(54,\\"2024-02-05 19:54:00+06\\")","(55,\\"2024-02-05 19:56:00+06\\")","(56,\\"2024-02-05 19:58:00+06\\")","(57,\\"2024-02-05 20:00:00+06\\")","(58,\\"2024-02-05 20:02:00+06\\")","(59,\\"2024-02-05 20:04:00+06\\")","(60,\\"2024-02-05 20:06:00+06\\")","(61,\\"2024-02-05 20:08:00+06\\")","(62,\\"2024-02-05 20:10:00+06\\")","(63,\\"2024-02-05 20:12:00+06\\")","(70,\\"2024-02-05 20:14:00+06\\")"}	from_buet	Ba-98-5568	t	polash	nazmul	f	mahmud64	t
1989	2024-02-05 23:30:00+06	7	evening	{"(50,\\"2024-02-05 23:30:00+06\\")","(51,\\"2024-02-05 23:38:00+06\\")","(52,\\"2024-02-05 23:40:00+06\\")","(53,\\"2024-02-05 23:42:00+06\\")","(54,\\"2024-02-05 23:44:00+06\\")","(55,\\"2024-02-05 23:46:00+06\\")","(56,\\"2024-02-05 23:48:00+06\\")","(57,\\"2024-02-05 23:50:00+06\\")","(58,\\"2024-02-05 23:52:00+06\\")","(59,\\"2024-02-05 23:54:00+06\\")","(60,\\"2024-02-05 23:56:00+06\\")","(61,\\"2024-02-05 23:58:00+06\\")","(62,\\"2024-02-05 00:00:00+06\\")","(63,\\"2024-02-05 00:02:00+06\\")","(70,\\"2024-02-05 00:04:00+06\\")"}	from_buet	Ba-98-5568	t	polash	nazmul	f	mahmud64	t
1993	2024-02-05 12:10:00+06	8	morning	{"(64,\\"2024-02-05 12:10:00+06\\")","(65,\\"2024-02-05 12:13:00+06\\")","(66,\\"2024-02-05 12:18:00+06\\")","(67,\\"2024-02-05 12:20:00+06\\")","(68,\\"2024-02-05 12:22:00+06\\")","(69,\\"2024-02-05 12:25:00+06\\")","(70,\\"2024-02-05 12:40:00+06\\")"}	to_buet	Ba-97-6734	t	monu67	nazmul	f	farid99	t
1994	2024-02-05 19:40:00+06	8	afternoon	{"(64,\\"2024-02-05 19:40:00+06\\")","(65,\\"2024-02-05 19:55:00+06\\")","(66,\\"2024-02-05 19:58:00+06\\")","(67,\\"2024-02-05 20:01:00+06\\")","(68,\\"2024-02-05 20:04:00+06\\")","(69,\\"2024-02-05 20:07:00+06\\")","(70,\\"2024-02-05 20:10:00+06\\")"}	from_buet	Ba-97-6734	t	monu67	nazmul	f	farid99	t
1995	2024-02-05 23:30:00+06	8	evening	{"(64,\\"2024-02-05 23:30:00+06\\")","(65,\\"2024-02-05 23:45:00+06\\")","(66,\\"2024-02-05 23:48:00+06\\")","(67,\\"2024-02-05 23:51:00+06\\")","(68,\\"2024-02-05 23:54:00+06\\")","(69,\\"2024-02-05 23:57:00+06\\")","(70,\\"2024-02-05 00:00:00+06\\")"}	from_buet	Ba-97-6734	t	monu67	nazmul	f	farid99	t
1996	2024-02-01 12:55:00+06	2	morning	{"(12,\\"2024-02-01 12:55:00+06\\")","(13,\\"2024-02-01 12:57:00+06\\")","(14,\\"2024-02-01 12:59:00+06\\")","(15,\\"2024-02-01 13:01:00+06\\")","(16,\\"2024-02-01 13:03:00+06\\")","(70,\\"2024-02-01 13:15:00+06\\")"}	to_buet	Ba-48-5757	t	arif43	\N	f	mahbub777	t
1997	2024-02-01 19:40:00+06	2	afternoon	{"(12,\\"2024-02-01 19:40:00+06\\")","(13,\\"2024-02-01 19:52:00+06\\")","(14,\\"2024-02-01 19:54:00+06\\")","(15,\\"2024-02-01 19:57:00+06\\")","(16,\\"2024-02-01 20:00:00+06\\")","(70,\\"2024-02-01 20:03:00+06\\")"}	from_buet	Ba-48-5757	t	arif43	\N	f	mahbub777	t
1998	2024-02-01 23:30:00+06	2	evening	{"(12,\\"2024-02-01 23:30:00+06\\")","(13,\\"2024-02-01 23:42:00+06\\")","(14,\\"2024-02-01 23:45:00+06\\")","(15,\\"2024-02-01 23:48:00+06\\")","(16,\\"2024-02-01 23:51:00+06\\")","(70,\\"2024-02-01 23:54:00+06\\")"}	from_buet	Ba-48-5757	t	arif43	\N	f	mahbub777	t
1999	2024-02-01 12:40:00+06	3	morning	{"(17,\\"2024-02-01 12:40:00+06\\")","(18,\\"2024-02-01 12:42:00+06\\")","(19,\\"2024-02-01 12:44:00+06\\")","(20,\\"2024-02-01 12:46:00+06\\")","(21,\\"2024-02-01 12:48:00+06\\")","(22,\\"2024-02-01 12:50:00+06\\")","(23,\\"2024-02-01 12:52:00+06\\")","(24,\\"2024-02-01 12:54:00+06\\")","(25,\\"2024-02-01 12:57:00+06\\")","(26,\\"2024-02-01 13:00:00+06\\")","(70,\\"2024-02-01 13:15:00+06\\")"}	to_buet	Ba-34-7413	t	nizam88	\N	f	farid99	t
2000	2024-02-01 19:40:00+06	3	afternoon	{"(17,\\"2024-02-01 19:40:00+06\\")","(18,\\"2024-02-01 19:55:00+06\\")","(19,\\"2024-02-01 19:58:00+06\\")","(20,\\"2024-02-01 20:00:00+06\\")","(21,\\"2024-02-01 20:02:00+06\\")","(22,\\"2024-02-01 20:04:00+06\\")","(23,\\"2024-02-01 20:06:00+06\\")","(24,\\"2024-02-01 20:08:00+06\\")","(25,\\"2024-02-01 20:10:00+06\\")","(26,\\"2024-02-01 20:12:00+06\\")","(70,\\"2024-02-01 20:14:00+06\\")"}	from_buet	Ba-34-7413	t	nizam88	\N	f	farid99	t
2001	2024-02-01 23:30:00+06	3	evening	{"(17,\\"2024-02-01 23:30:00+06\\")","(18,\\"2024-02-01 23:45:00+06\\")","(19,\\"2024-02-01 23:48:00+06\\")","(20,\\"2024-02-01 23:50:00+06\\")","(21,\\"2024-02-01 23:52:00+06\\")","(22,\\"2024-02-01 23:54:00+06\\")","(23,\\"2024-02-01 23:56:00+06\\")","(24,\\"2024-02-01 23:58:00+06\\")","(25,\\"2024-02-01 00:00:00+06\\")","(26,\\"2024-02-01 00:02:00+06\\")","(70,\\"2024-02-01 00:04:00+06\\")"}	from_buet	Ba-34-7413	t	nizam88	\N	f	farid99	t
2002	2024-02-01 12:40:00+06	4	morning	{"(27,\\"2024-02-01 12:40:00+06\\")","(28,\\"2024-02-01 12:42:00+06\\")","(29,\\"2024-02-01 12:44:00+06\\")","(30,\\"2024-02-01 12:46:00+06\\")","(31,\\"2024-02-01 12:50:00+06\\")","(32,\\"2024-02-01 12:52:00+06\\")","(33,\\"2024-02-01 12:54:00+06\\")","(34,\\"2024-02-01 12:58:00+06\\")","(35,\\"2024-02-01 13:00:00+06\\")","(70,\\"2024-02-01 13:10:00+06\\")"}	to_buet	Ba-20-3066	t	nazrul6	\N	f	mahmud64	t
2003	2024-02-01 19:40:00+06	4	afternoon	{"(27,\\"2024-02-01 19:40:00+06\\")","(28,\\"2024-02-01 19:50:00+06\\")","(29,\\"2024-02-01 19:52:00+06\\")","(30,\\"2024-02-01 19:54:00+06\\")","(31,\\"2024-02-01 19:56:00+06\\")","(32,\\"2024-02-01 19:58:00+06\\")","(33,\\"2024-02-01 20:00:00+06\\")","(34,\\"2024-02-01 20:02:00+06\\")","(35,\\"2024-02-01 20:04:00+06\\")","(70,\\"2024-02-01 20:06:00+06\\")"}	from_buet	Ba-20-3066	t	nazrul6	\N	f	mahmud64	t
2004	2024-02-01 23:30:00+06	4	evening	{"(27,\\"2024-02-01 23:30:00+06\\")","(28,\\"2024-02-01 23:40:00+06\\")","(29,\\"2024-02-01 23:42:00+06\\")","(30,\\"2024-02-01 23:44:00+06\\")","(31,\\"2024-02-01 23:46:00+06\\")","(32,\\"2024-02-01 23:48:00+06\\")","(33,\\"2024-02-01 23:50:00+06\\")","(34,\\"2024-02-01 23:52:00+06\\")","(35,\\"2024-02-01 23:54:00+06\\")","(70,\\"2024-02-01 23:56:00+06\\")"}	from_buet	Ba-20-3066	t	nazrul6	\N	f	mahmud64	t
2005	2024-02-01 12:30:00+06	5	morning	{"(36,\\"2024-02-01 12:30:00+06\\")","(37,\\"2024-02-01 12:33:00+06\\")","(38,\\"2024-02-01 12:40:00+06\\")","(39,\\"2024-02-01 12:45:00+06\\")","(40,\\"2024-02-01 12:50:00+06\\")","(70,\\"2024-02-01 13:00:00+06\\")"}	to_buet	Ba-17-3886	t	aminhaque	\N	f	siddiq2	t
2006	2024-02-01 19:40:00+06	5	afternoon	{"(36,\\"2024-02-01 19:40:00+06\\")","(37,\\"2024-02-01 19:50:00+06\\")","(38,\\"2024-02-01 19:55:00+06\\")","(39,\\"2024-02-01 20:00:00+06\\")","(40,\\"2024-02-01 20:07:00+06\\")","(70,\\"2024-02-01 20:10:00+06\\")"}	from_buet	Ba-17-3886	t	aminhaque	\N	f	siddiq2	t
2007	2024-02-01 23:30:00+06	5	evening	{"(36,\\"2024-02-01 23:30:00+06\\")","(37,\\"2024-02-01 23:40:00+06\\")","(38,\\"2024-02-01 23:45:00+06\\")","(39,\\"2024-02-01 23:50:00+06\\")","(40,\\"2024-02-01 23:57:00+06\\")","(70,\\"2024-02-01 00:00:00+06\\")"}	from_buet	Ba-17-3886	t	aminhaque	\N	f	siddiq2	t
2011	2024-02-01 12:40:00+06	7	morning	{"(50,\\"2024-02-01 12:40:00+06\\")","(51,\\"2024-02-01 12:42:00+06\\")","(52,\\"2024-02-01 12:43:00+06\\")","(53,\\"2024-02-01 12:46:00+06\\")","(54,\\"2024-02-01 12:47:00+06\\")","(55,\\"2024-02-01 12:48:00+06\\")","(56,\\"2024-02-01 12:50:00+06\\")","(57,\\"2024-02-01 12:52:00+06\\")","(58,\\"2024-02-01 12:53:00+06\\")","(59,\\"2024-02-01 12:54:00+06\\")","(60,\\"2024-02-01 12:56:00+06\\")","(61,\\"2024-02-01 12:58:00+06\\")","(62,\\"2024-02-01 13:00:00+06\\")","(63,\\"2024-02-01 13:02:00+06\\")","(70,\\"2024-02-01 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	masud84	\N	f	shamsul54	t
2012	2024-02-01 19:40:00+06	7	afternoon	{"(50,\\"2024-02-01 19:40:00+06\\")","(51,\\"2024-02-01 19:48:00+06\\")","(52,\\"2024-02-01 19:50:00+06\\")","(53,\\"2024-02-01 19:52:00+06\\")","(54,\\"2024-02-01 19:54:00+06\\")","(55,\\"2024-02-01 19:56:00+06\\")","(56,\\"2024-02-01 19:58:00+06\\")","(57,\\"2024-02-01 20:00:00+06\\")","(58,\\"2024-02-01 20:02:00+06\\")","(59,\\"2024-02-01 20:04:00+06\\")","(60,\\"2024-02-01 20:06:00+06\\")","(61,\\"2024-02-01 20:08:00+06\\")","(62,\\"2024-02-01 20:10:00+06\\")","(63,\\"2024-02-01 20:12:00+06\\")","(70,\\"2024-02-01 20:14:00+06\\")"}	from_buet	Ba-24-8518	t	masud84	\N	f	shamsul54	t
2013	2024-02-01 23:30:00+06	7	evening	{"(50,\\"2024-02-01 23:30:00+06\\")","(51,\\"2024-02-01 23:38:00+06\\")","(52,\\"2024-02-01 23:40:00+06\\")","(53,\\"2024-02-01 23:42:00+06\\")","(54,\\"2024-02-01 23:44:00+06\\")","(55,\\"2024-02-01 23:46:00+06\\")","(56,\\"2024-02-01 23:48:00+06\\")","(57,\\"2024-02-01 23:50:00+06\\")","(58,\\"2024-02-01 23:52:00+06\\")","(59,\\"2024-02-01 23:54:00+06\\")","(60,\\"2024-02-01 23:56:00+06\\")","(61,\\"2024-02-01 23:58:00+06\\")","(62,\\"2024-02-01 00:00:00+06\\")","(63,\\"2024-02-01 00:02:00+06\\")","(70,\\"2024-02-01 00:04:00+06\\")"}	from_buet	Ba-24-8518	t	masud84	\N	f	shamsul54	t
2014	2024-02-01 12:15:00+06	1	morning	{"(1,\\"2024-02-01 12:15:00+06\\")","(2,\\"2024-02-01 12:18:00+06\\")","(3,\\"2024-02-01 12:20:00+06\\")","(4,\\"2024-02-01 12:23:00+06\\")","(5,\\"2024-02-01 12:26:00+06\\")","(6,\\"2024-02-01 12:29:00+06\\")","(7,\\"2024-02-01 12:49:00+06\\")","(8,\\"2024-02-01 12:51:00+06\\")","(9,\\"2024-02-01 12:53:00+06\\")","(10,\\"2024-02-01 12:55:00+06\\")","(11,\\"2024-02-01 12:58:00+06\\")","(70,\\"2024-02-01 13:05:00+06\\")"}	to_buet	Ba-22-4326	t	rahmatullah	\N	f	reyazul	t
2015	2024-02-01 19:40:00+06	1	afternoon	{"(1,\\"2024-02-01 19:40:00+06\\")","(2,\\"2024-02-01 19:47:00+06\\")","(3,\\"2024-02-01 19:50:00+06\\")","(4,\\"2024-02-01 19:52:00+06\\")","(5,\\"2024-02-01 19:54:00+06\\")","(6,\\"2024-02-01 20:06:00+06\\")","(7,\\"2024-02-01 20:09:00+06\\")","(8,\\"2024-02-01 20:12:00+06\\")","(9,\\"2024-02-01 20:15:00+06\\")","(10,\\"2024-02-01 20:18:00+06\\")","(11,\\"2024-02-01 20:21:00+06\\")","(70,\\"2024-02-01 20:24:00+06\\")"}	from_buet	Ba-22-4326	t	rahmatullah	\N	f	reyazul	t
2016	2024-02-01 23:30:00+06	1	evening	{"(1,\\"2024-02-01 23:30:00+06\\")","(2,\\"2024-02-01 23:37:00+06\\")","(3,\\"2024-02-01 23:40:00+06\\")","(4,\\"2024-02-01 23:42:00+06\\")","(5,\\"2024-02-01 23:44:00+06\\")","(6,\\"2024-02-01 23:56:00+06\\")","(7,\\"2024-02-01 23:59:00+06\\")","(8,\\"2024-02-01 00:02:00+06\\")","(9,\\"2024-02-01 00:05:00+06\\")","(10,\\"2024-02-01 00:08:00+06\\")","(11,\\"2024-02-01 00:11:00+06\\")","(70,\\"2024-02-01 00:14:00+06\\")"}	from_buet	Ba-22-4326	t	rahmatullah	\N	f	reyazul	t
2018	2024-02-01 19:40:00+06	8	afternoon	{"(64,\\"2024-02-01 19:40:00+06\\")","(65,\\"2024-02-01 19:55:00+06\\")","(66,\\"2024-02-01 19:58:00+06\\")","(67,\\"2024-02-01 20:01:00+06\\")","(68,\\"2024-02-01 20:04:00+06\\")","(69,\\"2024-02-01 20:07:00+06\\")","(70,\\"2024-02-01 20:10:00+06\\")"}	from_buet	Ba-85-4722	t	rashed3	\N	f	rashid56	t
2019	2024-02-01 23:30:00+06	8	evening	{"(64,\\"2024-02-01 23:30:00+06\\")","(65,\\"2024-02-01 23:45:00+06\\")","(66,\\"2024-02-01 23:48:00+06\\")","(67,\\"2024-02-01 23:51:00+06\\")","(68,\\"2024-02-01 23:54:00+06\\")","(69,\\"2024-02-01 23:57:00+06\\")","(70,\\"2024-02-01 00:00:00+06\\")"}	from_buet	Ba-85-4722	t	rashed3	\N	f	rashid56	t
2020	2024-02-02 12:55:00+06	2	morning	{"(12,\\"2024-02-02 12:55:00+06\\")","(13,\\"2024-02-02 12:57:00+06\\")","(14,\\"2024-02-02 12:59:00+06\\")","(15,\\"2024-02-02 13:01:00+06\\")","(16,\\"2024-02-02 13:03:00+06\\")","(70,\\"2024-02-02 13:15:00+06\\")"}	to_buet	Ba-24-8518	t	altaf78	\N	f	ASADUZZAMAN	t
2022	2024-02-02 23:30:00+06	2	evening	{"(12,\\"2024-02-02 23:30:00+06\\")","(13,\\"2024-02-02 23:42:00+06\\")","(14,\\"2024-02-02 23:45:00+06\\")","(15,\\"2024-02-02 23:48:00+06\\")","(16,\\"2024-02-02 23:51:00+06\\")","(70,\\"2024-02-02 23:54:00+06\\")"}	from_buet	Ba-24-8518	t	altaf78	\N	f	ASADUZZAMAN	t
2023	2024-02-02 12:40:00+06	3	morning	{"(17,\\"2024-02-02 12:40:00+06\\")","(18,\\"2024-02-02 12:42:00+06\\")","(19,\\"2024-02-02 12:44:00+06\\")","(20,\\"2024-02-02 12:46:00+06\\")","(21,\\"2024-02-02 12:48:00+06\\")","(22,\\"2024-02-02 12:50:00+06\\")","(23,\\"2024-02-02 12:52:00+06\\")","(24,\\"2024-02-02 12:54:00+06\\")","(25,\\"2024-02-02 12:57:00+06\\")","(26,\\"2024-02-02 13:00:00+06\\")","(70,\\"2024-02-02 13:15:00+06\\")"}	to_buet	Ba-69-8288	t	abdulkarim6	\N	f	nasir81	t
2024	2024-02-02 19:40:00+06	3	afternoon	{"(17,\\"2024-02-02 19:40:00+06\\")","(18,\\"2024-02-02 19:55:00+06\\")","(19,\\"2024-02-02 19:58:00+06\\")","(20,\\"2024-02-02 20:00:00+06\\")","(21,\\"2024-02-02 20:02:00+06\\")","(22,\\"2024-02-02 20:04:00+06\\")","(23,\\"2024-02-02 20:06:00+06\\")","(24,\\"2024-02-02 20:08:00+06\\")","(25,\\"2024-02-02 20:10:00+06\\")","(26,\\"2024-02-02 20:12:00+06\\")","(70,\\"2024-02-02 20:14:00+06\\")"}	from_buet	Ba-69-8288	t	abdulkarim6	\N	f	nasir81	t
2025	2024-02-02 23:30:00+06	3	evening	{"(17,\\"2024-02-02 23:30:00+06\\")","(18,\\"2024-02-02 23:45:00+06\\")","(19,\\"2024-02-02 23:48:00+06\\")","(20,\\"2024-02-02 23:50:00+06\\")","(21,\\"2024-02-02 23:52:00+06\\")","(22,\\"2024-02-02 23:54:00+06\\")","(23,\\"2024-02-02 23:56:00+06\\")","(24,\\"2024-02-02 23:58:00+06\\")","(25,\\"2024-02-02 00:00:00+06\\")","(26,\\"2024-02-02 00:02:00+06\\")","(70,\\"2024-02-02 00:04:00+06\\")"}	from_buet	Ba-69-8288	t	abdulkarim6	\N	f	nasir81	t
2026	2024-02-02 12:40:00+06	4	morning	{"(27,\\"2024-02-02 12:40:00+06\\")","(28,\\"2024-02-02 12:42:00+06\\")","(29,\\"2024-02-02 12:44:00+06\\")","(30,\\"2024-02-02 12:46:00+06\\")","(31,\\"2024-02-02 12:50:00+06\\")","(32,\\"2024-02-02 12:52:00+06\\")","(33,\\"2024-02-02 12:54:00+06\\")","(34,\\"2024-02-02 12:58:00+06\\")","(35,\\"2024-02-02 13:00:00+06\\")","(70,\\"2024-02-02 13:10:00+06\\")"}	to_buet	Ba-97-6734	t	nizam88	\N	f	alamgir	t
2027	2024-02-02 19:40:00+06	4	afternoon	{"(27,\\"2024-02-02 19:40:00+06\\")","(28,\\"2024-02-02 19:50:00+06\\")","(29,\\"2024-02-02 19:52:00+06\\")","(30,\\"2024-02-02 19:54:00+06\\")","(31,\\"2024-02-02 19:56:00+06\\")","(32,\\"2024-02-02 19:58:00+06\\")","(33,\\"2024-02-02 20:00:00+06\\")","(34,\\"2024-02-02 20:02:00+06\\")","(35,\\"2024-02-02 20:04:00+06\\")","(70,\\"2024-02-02 20:06:00+06\\")"}	from_buet	Ba-97-6734	t	nizam88	\N	f	alamgir	t
2028	2024-02-02 23:30:00+06	4	evening	{"(27,\\"2024-02-02 23:30:00+06\\")","(28,\\"2024-02-02 23:40:00+06\\")","(29,\\"2024-02-02 23:42:00+06\\")","(30,\\"2024-02-02 23:44:00+06\\")","(31,\\"2024-02-02 23:46:00+06\\")","(32,\\"2024-02-02 23:48:00+06\\")","(33,\\"2024-02-02 23:50:00+06\\")","(34,\\"2024-02-02 23:52:00+06\\")","(35,\\"2024-02-02 23:54:00+06\\")","(70,\\"2024-02-02 23:56:00+06\\")"}	from_buet	Ba-97-6734	t	nizam88	\N	f	alamgir	t
2030	2024-02-02 19:40:00+06	5	afternoon	{"(36,\\"2024-02-02 19:40:00+06\\")","(37,\\"2024-02-02 19:50:00+06\\")","(38,\\"2024-02-02 19:55:00+06\\")","(39,\\"2024-02-02 20:00:00+06\\")","(40,\\"2024-02-02 20:07:00+06\\")","(70,\\"2024-02-02 20:10:00+06\\")"}	from_buet	Ba-19-0569	t	rahmatullah	\N	f	khairul	t
2031	2024-02-02 23:30:00+06	5	evening	{"(36,\\"2024-02-02 23:30:00+06\\")","(37,\\"2024-02-02 23:40:00+06\\")","(38,\\"2024-02-02 23:45:00+06\\")","(39,\\"2024-02-02 23:50:00+06\\")","(40,\\"2024-02-02 23:57:00+06\\")","(70,\\"2024-02-02 00:00:00+06\\")"}	from_buet	Ba-19-0569	t	rahmatullah	\N	f	khairul	t
2032	2024-02-02 12:40:00+06	6	morning	{"(41,\\"2024-02-02 12:40:00+06\\")","(42,\\"2024-02-02 12:42:00+06\\")","(43,\\"2024-02-02 12:45:00+06\\")","(44,\\"2024-02-02 12:47:00+06\\")","(45,\\"2024-02-02 12:49:00+06\\")","(46,\\"2024-02-02 12:51:00+06\\")","(47,\\"2024-02-02 12:52:00+06\\")","(48,\\"2024-02-02 12:53:00+06\\")","(49,\\"2024-02-02 12:54:00+06\\")","(70,\\"2024-02-02 13:10:00+06\\")"}	to_buet	Ba-77-7044	t	polash	\N	f	jamal7898	t
2034	2024-02-02 23:30:00+06	6	evening	{"(41,\\"2024-02-02 23:30:00+06\\")","(42,\\"2024-02-02 23:46:00+06\\")","(43,\\"2024-02-02 23:48:00+06\\")","(44,\\"2024-02-02 23:50:00+06\\")","(45,\\"2024-02-02 23:52:00+06\\")","(46,\\"2024-02-02 23:54:00+06\\")","(47,\\"2024-02-02 23:56:00+06\\")","(48,\\"2024-02-02 23:58:00+06\\")","(49,\\"2024-02-02 00:00:00+06\\")","(70,\\"2024-02-02 00:02:00+06\\")"}	from_buet	Ba-77-7044	t	polash	\N	f	jamal7898	t
2035	2024-02-02 12:40:00+06	7	morning	{"(50,\\"2024-02-02 12:40:00+06\\")","(51,\\"2024-02-02 12:42:00+06\\")","(52,\\"2024-02-02 12:43:00+06\\")","(53,\\"2024-02-02 12:46:00+06\\")","(54,\\"2024-02-02 12:47:00+06\\")","(55,\\"2024-02-02 12:48:00+06\\")","(56,\\"2024-02-02 12:50:00+06\\")","(57,\\"2024-02-02 12:52:00+06\\")","(58,\\"2024-02-02 12:53:00+06\\")","(59,\\"2024-02-02 12:54:00+06\\")","(60,\\"2024-02-02 12:56:00+06\\")","(61,\\"2024-02-02 12:58:00+06\\")","(62,\\"2024-02-02 13:00:00+06\\")","(63,\\"2024-02-02 13:02:00+06\\")","(70,\\"2024-02-02 13:00:00+06\\")"}	to_buet	Ba-63-1146	t	fazlu77	\N	f	shamsul54	t
2038	2024-02-02 12:15:00+06	1	morning	{"(1,\\"2024-02-02 12:15:00+06\\")","(2,\\"2024-02-02 12:18:00+06\\")","(3,\\"2024-02-02 12:20:00+06\\")","(4,\\"2024-02-02 12:23:00+06\\")","(5,\\"2024-02-02 12:26:00+06\\")","(6,\\"2024-02-02 12:29:00+06\\")","(7,\\"2024-02-02 12:49:00+06\\")","(8,\\"2024-02-02 12:51:00+06\\")","(9,\\"2024-02-02 12:53:00+06\\")","(10,\\"2024-02-02 12:55:00+06\\")","(11,\\"2024-02-02 12:58:00+06\\")","(70,\\"2024-02-02 13:05:00+06\\")"}	to_buet	Ba-93-6087	t	sohel55	\N	f	rashid56	t
2039	2024-02-02 19:40:00+06	1	afternoon	{"(1,\\"2024-02-02 19:40:00+06\\")","(2,\\"2024-02-02 19:47:00+06\\")","(3,\\"2024-02-02 19:50:00+06\\")","(4,\\"2024-02-02 19:52:00+06\\")","(5,\\"2024-02-02 19:54:00+06\\")","(6,\\"2024-02-02 20:06:00+06\\")","(7,\\"2024-02-02 20:09:00+06\\")","(8,\\"2024-02-02 20:12:00+06\\")","(9,\\"2024-02-02 20:15:00+06\\")","(10,\\"2024-02-02 20:18:00+06\\")","(11,\\"2024-02-02 20:21:00+06\\")","(70,\\"2024-02-02 20:24:00+06\\")"}	from_buet	Ba-93-6087	t	sohel55	\N	f	rashid56	t
2040	2024-02-02 23:30:00+06	1	evening	{"(1,\\"2024-02-02 23:30:00+06\\")","(2,\\"2024-02-02 23:37:00+06\\")","(3,\\"2024-02-02 23:40:00+06\\")","(4,\\"2024-02-02 23:42:00+06\\")","(5,\\"2024-02-02 23:44:00+06\\")","(6,\\"2024-02-02 23:56:00+06\\")","(7,\\"2024-02-02 23:59:00+06\\")","(8,\\"2024-02-02 00:02:00+06\\")","(9,\\"2024-02-02 00:05:00+06\\")","(10,\\"2024-02-02 00:08:00+06\\")","(11,\\"2024-02-02 00:11:00+06\\")","(70,\\"2024-02-02 00:14:00+06\\")"}	from_buet	Ba-93-6087	t	sohel55	\N	f	rashid56	t
2043	2024-02-02 23:30:00+06	8	evening	{"(64,\\"2024-02-02 23:30:00+06\\")","(65,\\"2024-02-02 23:45:00+06\\")","(66,\\"2024-02-02 23:48:00+06\\")","(67,\\"2024-02-02 23:51:00+06\\")","(68,\\"2024-02-02 23:54:00+06\\")","(69,\\"2024-02-02 23:57:00+06\\")","(70,\\"2024-02-02 00:00:00+06\\")"}	from_buet	Ba-20-3066	t	altaf78	\N	f	reyazul	t
2021	2024-02-02 19:40:00+06	2	afternoon	{"(12,\\"2024-02-02 19:40:00+06\\")","(13,\\"2024-02-02 19:52:00+06\\")","(14,\\"2024-02-02 19:54:00+06\\")","(15,\\"2024-02-02 19:57:00+06\\")","(16,\\"2024-02-02 20:00:00+06\\")","(70,\\"2024-02-02 20:03:00+06\\")"}	from_buet	Ba-24-8518	t	altaf78	\N	f	ASADUZZAMAN	t
2044	2024-02-03 12:55:00+06	2	morning	{"(12,\\"2024-02-03 12:55:00+06\\")","(13,\\"2024-02-03 12:57:00+06\\")","(14,\\"2024-02-03 12:59:00+06\\")","(15,\\"2024-02-03 13:01:00+06\\")","(16,\\"2024-02-03 13:03:00+06\\")","(70,\\"2024-02-03 13:15:00+06\\")"}	to_buet	Ba-93-6087	t	fazlu77	nazmul	f	reyazul	t
2045	2024-02-03 19:40:00+06	2	afternoon	{"(12,\\"2024-02-03 19:40:00+06\\")","(13,\\"2024-02-03 19:52:00+06\\")","(14,\\"2024-02-03 19:54:00+06\\")","(15,\\"2024-02-03 19:57:00+06\\")","(16,\\"2024-02-03 20:00:00+06\\")","(70,\\"2024-02-03 20:03:00+06\\")"}	from_buet	Ba-93-6087	t	fazlu77	nazmul	f	reyazul	t
2046	2024-02-03 23:30:00+06	2	evening	{"(12,\\"2024-02-03 23:30:00+06\\")","(13,\\"2024-02-03 23:42:00+06\\")","(14,\\"2024-02-03 23:45:00+06\\")","(15,\\"2024-02-03 23:48:00+06\\")","(16,\\"2024-02-03 23:51:00+06\\")","(70,\\"2024-02-03 23:54:00+06\\")"}	from_buet	Ba-93-6087	t	fazlu77	nazmul	f	reyazul	t
2047	2024-02-03 12:40:00+06	3	morning	{"(17,\\"2024-02-03 12:40:00+06\\")","(18,\\"2024-02-03 12:42:00+06\\")","(19,\\"2024-02-03 12:44:00+06\\")","(20,\\"2024-02-03 12:46:00+06\\")","(21,\\"2024-02-03 12:48:00+06\\")","(22,\\"2024-02-03 12:50:00+06\\")","(23,\\"2024-02-03 12:52:00+06\\")","(24,\\"2024-02-03 12:54:00+06\\")","(25,\\"2024-02-03 12:57:00+06\\")","(26,\\"2024-02-03 13:00:00+06\\")","(70,\\"2024-02-03 13:15:00+06\\")"}	to_buet	Ba-34-7413	t	monu67	nazmul	f	abdulbari4	t
2127	2024-02-06 23:30:00+06	5	evening	{"(36,\\"2024-02-06 23:30:00+06\\")","(37,\\"2024-02-06 23:40:00+06\\")","(38,\\"2024-02-06 23:45:00+06\\")","(39,\\"2024-02-06 23:50:00+06\\")","(40,\\"2024-02-06 23:57:00+06\\")","(70,\\"2024-02-06 00:00:00+06\\")"}	from_buet	Ba-48-5757	t	rashed3	nazmul	f	mahmud64	t
2048	2024-02-03 19:40:00+06	3	afternoon	{"(17,\\"2024-02-03 19:40:00+06\\")","(18,\\"2024-02-03 19:55:00+06\\")","(19,\\"2024-02-03 19:58:00+06\\")","(20,\\"2024-02-03 20:00:00+06\\")","(21,\\"2024-02-03 20:02:00+06\\")","(22,\\"2024-02-03 20:04:00+06\\")","(23,\\"2024-02-03 20:06:00+06\\")","(24,\\"2024-02-03 20:08:00+06\\")","(25,\\"2024-02-03 20:10:00+06\\")","(26,\\"2024-02-03 20:12:00+06\\")","(70,\\"2024-02-03 20:14:00+06\\")"}	from_buet	Ba-34-7413	t	monu67	nazmul	f	abdulbari4	t
2049	2024-02-03 23:30:00+06	3	evening	{"(17,\\"2024-02-03 23:30:00+06\\")","(18,\\"2024-02-03 23:45:00+06\\")","(19,\\"2024-02-03 23:48:00+06\\")","(20,\\"2024-02-03 23:50:00+06\\")","(21,\\"2024-02-03 23:52:00+06\\")","(22,\\"2024-02-03 23:54:00+06\\")","(23,\\"2024-02-03 23:56:00+06\\")","(24,\\"2024-02-03 23:58:00+06\\")","(25,\\"2024-02-03 00:00:00+06\\")","(26,\\"2024-02-03 00:02:00+06\\")","(70,\\"2024-02-03 00:04:00+06\\")"}	from_buet	Ba-34-7413	t	monu67	nazmul	f	abdulbari4	t
2050	2024-02-03 12:40:00+06	4	morning	{"(27,\\"2024-02-03 12:40:00+06\\")","(28,\\"2024-02-03 12:42:00+06\\")","(29,\\"2024-02-03 12:44:00+06\\")","(30,\\"2024-02-03 12:46:00+06\\")","(31,\\"2024-02-03 12:50:00+06\\")","(32,\\"2024-02-03 12:52:00+06\\")","(33,\\"2024-02-03 12:54:00+06\\")","(34,\\"2024-02-03 12:58:00+06\\")","(35,\\"2024-02-03 13:00:00+06\\")","(70,\\"2024-02-03 13:10:00+06\\")"}	to_buet	Ba-48-5757	t	nizam88	nazmul	f	farid99	t
2051	2024-02-03 19:40:00+06	4	afternoon	{"(27,\\"2024-02-03 19:40:00+06\\")","(28,\\"2024-02-03 19:50:00+06\\")","(29,\\"2024-02-03 19:52:00+06\\")","(30,\\"2024-02-03 19:54:00+06\\")","(31,\\"2024-02-03 19:56:00+06\\")","(32,\\"2024-02-03 19:58:00+06\\")","(33,\\"2024-02-03 20:00:00+06\\")","(34,\\"2024-02-03 20:02:00+06\\")","(35,\\"2024-02-03 20:04:00+06\\")","(70,\\"2024-02-03 20:06:00+06\\")"}	from_buet	Ba-48-5757	t	nizam88	nazmul	f	farid99	t
2052	2024-02-03 23:30:00+06	4	evening	{"(27,\\"2024-02-03 23:30:00+06\\")","(28,\\"2024-02-03 23:40:00+06\\")","(29,\\"2024-02-03 23:42:00+06\\")","(30,\\"2024-02-03 23:44:00+06\\")","(31,\\"2024-02-03 23:46:00+06\\")","(32,\\"2024-02-03 23:48:00+06\\")","(33,\\"2024-02-03 23:50:00+06\\")","(34,\\"2024-02-03 23:52:00+06\\")","(35,\\"2024-02-03 23:54:00+06\\")","(70,\\"2024-02-03 23:56:00+06\\")"}	from_buet	Ba-48-5757	t	nizam88	nazmul	f	farid99	t
2056	2024-02-03 12:40:00+06	6	morning	{"(41,\\"2024-02-03 12:40:00+06\\")","(42,\\"2024-02-03 12:42:00+06\\")","(43,\\"2024-02-03 12:45:00+06\\")","(44,\\"2024-02-03 12:47:00+06\\")","(45,\\"2024-02-03 12:49:00+06\\")","(46,\\"2024-02-03 12:51:00+06\\")","(47,\\"2024-02-03 12:52:00+06\\")","(48,\\"2024-02-03 12:53:00+06\\")","(49,\\"2024-02-03 12:54:00+06\\")","(70,\\"2024-02-03 13:10:00+06\\")"}	to_buet	Ba-69-8288	t	aminhaque	nazmul	f	rashid56	t
2057	2024-02-03 19:40:00+06	6	afternoon	{"(41,\\"2024-02-03 19:40:00+06\\")","(42,\\"2024-02-03 19:56:00+06\\")","(43,\\"2024-02-03 19:58:00+06\\")","(44,\\"2024-02-03 20:00:00+06\\")","(45,\\"2024-02-03 20:02:00+06\\")","(46,\\"2024-02-03 20:04:00+06\\")","(47,\\"2024-02-03 20:06:00+06\\")","(48,\\"2024-02-03 20:08:00+06\\")","(49,\\"2024-02-03 20:10:00+06\\")","(70,\\"2024-02-03 20:12:00+06\\")"}	from_buet	Ba-69-8288	t	aminhaque	nazmul	f	rashid56	t
2058	2024-02-03 23:30:00+06	6	evening	{"(41,\\"2024-02-03 23:30:00+06\\")","(42,\\"2024-02-03 23:46:00+06\\")","(43,\\"2024-02-03 23:48:00+06\\")","(44,\\"2024-02-03 23:50:00+06\\")","(45,\\"2024-02-03 23:52:00+06\\")","(46,\\"2024-02-03 23:54:00+06\\")","(47,\\"2024-02-03 23:56:00+06\\")","(48,\\"2024-02-03 23:58:00+06\\")","(49,\\"2024-02-03 00:00:00+06\\")","(70,\\"2024-02-03 00:02:00+06\\")"}	from_buet	Ba-69-8288	t	aminhaque	nazmul	f	rashid56	t
2059	2024-02-03 12:40:00+06	7	morning	{"(50,\\"2024-02-03 12:40:00+06\\")","(51,\\"2024-02-03 12:42:00+06\\")","(52,\\"2024-02-03 12:43:00+06\\")","(53,\\"2024-02-03 12:46:00+06\\")","(54,\\"2024-02-03 12:47:00+06\\")","(55,\\"2024-02-03 12:48:00+06\\")","(56,\\"2024-02-03 12:50:00+06\\")","(57,\\"2024-02-03 12:52:00+06\\")","(58,\\"2024-02-03 12:53:00+06\\")","(59,\\"2024-02-03 12:54:00+06\\")","(60,\\"2024-02-03 12:56:00+06\\")","(61,\\"2024-02-03 12:58:00+06\\")","(62,\\"2024-02-03 13:00:00+06\\")","(63,\\"2024-02-03 13:02:00+06\\")","(70,\\"2024-02-03 13:00:00+06\\")"}	to_buet	Ba-63-1146	t	polash	nazmul	f	nasir81	t
2060	2024-02-03 19:40:00+06	7	afternoon	{"(50,\\"2024-02-03 19:40:00+06\\")","(51,\\"2024-02-03 19:48:00+06\\")","(52,\\"2024-02-03 19:50:00+06\\")","(53,\\"2024-02-03 19:52:00+06\\")","(54,\\"2024-02-03 19:54:00+06\\")","(55,\\"2024-02-03 19:56:00+06\\")","(56,\\"2024-02-03 19:58:00+06\\")","(57,\\"2024-02-03 20:00:00+06\\")","(58,\\"2024-02-03 20:02:00+06\\")","(59,\\"2024-02-03 20:04:00+06\\")","(60,\\"2024-02-03 20:06:00+06\\")","(61,\\"2024-02-03 20:08:00+06\\")","(62,\\"2024-02-03 20:10:00+06\\")","(63,\\"2024-02-03 20:12:00+06\\")","(70,\\"2024-02-03 20:14:00+06\\")"}	from_buet	Ba-63-1146	t	polash	nazmul	f	nasir81	t
2061	2024-02-03 23:30:00+06	7	evening	{"(50,\\"2024-02-03 23:30:00+06\\")","(51,\\"2024-02-03 23:38:00+06\\")","(52,\\"2024-02-03 23:40:00+06\\")","(53,\\"2024-02-03 23:42:00+06\\")","(54,\\"2024-02-03 23:44:00+06\\")","(55,\\"2024-02-03 23:46:00+06\\")","(56,\\"2024-02-03 23:48:00+06\\")","(57,\\"2024-02-03 23:50:00+06\\")","(58,\\"2024-02-03 23:52:00+06\\")","(59,\\"2024-02-03 23:54:00+06\\")","(60,\\"2024-02-03 23:56:00+06\\")","(61,\\"2024-02-03 23:58:00+06\\")","(62,\\"2024-02-03 00:00:00+06\\")","(63,\\"2024-02-03 00:02:00+06\\")","(70,\\"2024-02-03 00:04:00+06\\")"}	from_buet	Ba-63-1146	t	polash	nazmul	f	nasir81	t
2062	2024-02-03 12:15:00+06	1	morning	{"(1,\\"2024-02-03 12:15:00+06\\")","(2,\\"2024-02-03 12:18:00+06\\")","(3,\\"2024-02-03 12:20:00+06\\")","(4,\\"2024-02-03 12:23:00+06\\")","(5,\\"2024-02-03 12:26:00+06\\")","(6,\\"2024-02-03 12:29:00+06\\")","(7,\\"2024-02-03 12:49:00+06\\")","(8,\\"2024-02-03 12:51:00+06\\")","(9,\\"2024-02-03 12:53:00+06\\")","(10,\\"2024-02-03 12:55:00+06\\")","(11,\\"2024-02-03 12:58:00+06\\")","(70,\\"2024-02-03 13:05:00+06\\")"}	to_buet	Ba-97-6734	t	shahid88	nazmul	f	azim990	t
2063	2024-02-03 19:40:00+06	1	afternoon	{"(1,\\"2024-02-03 19:40:00+06\\")","(2,\\"2024-02-03 19:47:00+06\\")","(3,\\"2024-02-03 19:50:00+06\\")","(4,\\"2024-02-03 19:52:00+06\\")","(5,\\"2024-02-03 19:54:00+06\\")","(6,\\"2024-02-03 20:06:00+06\\")","(7,\\"2024-02-03 20:09:00+06\\")","(8,\\"2024-02-03 20:12:00+06\\")","(9,\\"2024-02-03 20:15:00+06\\")","(10,\\"2024-02-03 20:18:00+06\\")","(11,\\"2024-02-03 20:21:00+06\\")","(70,\\"2024-02-03 20:24:00+06\\")"}	from_buet	Ba-97-6734	t	shahid88	nazmul	f	azim990	t
2064	2024-02-03 23:30:00+06	1	evening	{"(1,\\"2024-02-03 23:30:00+06\\")","(2,\\"2024-02-03 23:37:00+06\\")","(3,\\"2024-02-03 23:40:00+06\\")","(4,\\"2024-02-03 23:42:00+06\\")","(5,\\"2024-02-03 23:44:00+06\\")","(6,\\"2024-02-03 23:56:00+06\\")","(7,\\"2024-02-03 23:59:00+06\\")","(8,\\"2024-02-03 00:02:00+06\\")","(9,\\"2024-02-03 00:05:00+06\\")","(10,\\"2024-02-03 00:08:00+06\\")","(11,\\"2024-02-03 00:11:00+06\\")","(70,\\"2024-02-03 00:14:00+06\\")"}	from_buet	Ba-97-6734	t	shahid88	nazmul	f	azim990	t
2065	2024-02-03 12:10:00+06	8	morning	{"(64,\\"2024-02-03 12:10:00+06\\")","(65,\\"2024-02-03 12:13:00+06\\")","(66,\\"2024-02-03 12:18:00+06\\")","(67,\\"2024-02-03 12:20:00+06\\")","(68,\\"2024-02-03 12:22:00+06\\")","(69,\\"2024-02-03 12:25:00+06\\")","(70,\\"2024-02-03 12:40:00+06\\")"}	to_buet	Ba-36-1921	t	nazrul6	nazmul	f	mahabhu	t
2066	2024-02-03 19:40:00+06	8	afternoon	{"(64,\\"2024-02-03 19:40:00+06\\")","(65,\\"2024-02-03 19:55:00+06\\")","(66,\\"2024-02-03 19:58:00+06\\")","(67,\\"2024-02-03 20:01:00+06\\")","(68,\\"2024-02-03 20:04:00+06\\")","(69,\\"2024-02-03 20:07:00+06\\")","(70,\\"2024-02-03 20:10:00+06\\")"}	from_buet	Ba-36-1921	t	nazrul6	nazmul	f	mahabhu	t
2067	2024-02-03 23:30:00+06	8	evening	{"(64,\\"2024-02-03 23:30:00+06\\")","(65,\\"2024-02-03 23:45:00+06\\")","(66,\\"2024-02-03 23:48:00+06\\")","(67,\\"2024-02-03 23:51:00+06\\")","(68,\\"2024-02-03 23:54:00+06\\")","(69,\\"2024-02-03 23:57:00+06\\")","(70,\\"2024-02-03 00:00:00+06\\")"}	from_buet	Ba-36-1921	t	nazrul6	nazmul	f	mahabhu	t
2068	2024-02-04 12:55:00+06	2	morning	{"(12,\\"2024-02-04 12:55:00+06\\")","(13,\\"2024-02-04 12:57:00+06\\")","(14,\\"2024-02-04 12:59:00+06\\")","(15,\\"2024-02-04 13:01:00+06\\")","(16,\\"2024-02-04 13:03:00+06\\")","(70,\\"2024-02-04 13:15:00+06\\")"}	to_buet	Ba-98-5568	t	rahmatullah	nazmul	f	mahmud64	t
2069	2024-02-04 19:40:00+06	2	afternoon	{"(12,\\"2024-02-04 19:40:00+06\\")","(13,\\"2024-02-04 19:52:00+06\\")","(14,\\"2024-02-04 19:54:00+06\\")","(15,\\"2024-02-04 19:57:00+06\\")","(16,\\"2024-02-04 20:00:00+06\\")","(70,\\"2024-02-04 20:03:00+06\\")"}	from_buet	Ba-98-5568	t	rahmatullah	nazmul	f	mahmud64	t
2070	2024-02-04 23:30:00+06	2	evening	{"(12,\\"2024-02-04 23:30:00+06\\")","(13,\\"2024-02-04 23:42:00+06\\")","(14,\\"2024-02-04 23:45:00+06\\")","(15,\\"2024-02-04 23:48:00+06\\")","(16,\\"2024-02-04 23:51:00+06\\")","(70,\\"2024-02-04 23:54:00+06\\")"}	from_buet	Ba-98-5568	t	rahmatullah	nazmul	f	mahmud64	t
2071	2024-02-04 12:40:00+06	3	morning	{"(17,\\"2024-02-04 12:40:00+06\\")","(18,\\"2024-02-04 12:42:00+06\\")","(19,\\"2024-02-04 12:44:00+06\\")","(20,\\"2024-02-04 12:46:00+06\\")","(21,\\"2024-02-04 12:48:00+06\\")","(22,\\"2024-02-04 12:50:00+06\\")","(23,\\"2024-02-04 12:52:00+06\\")","(24,\\"2024-02-04 12:54:00+06\\")","(25,\\"2024-02-04 12:57:00+06\\")","(26,\\"2024-02-04 13:00:00+06\\")","(70,\\"2024-02-04 13:15:00+06\\")"}	to_buet	Ba-20-3066	t	monu67	nazmul	f	alamgir	t
2072	2024-02-04 19:40:00+06	3	afternoon	{"(17,\\"2024-02-04 19:40:00+06\\")","(18,\\"2024-02-04 19:55:00+06\\")","(19,\\"2024-02-04 19:58:00+06\\")","(20,\\"2024-02-04 20:00:00+06\\")","(21,\\"2024-02-04 20:02:00+06\\")","(22,\\"2024-02-04 20:04:00+06\\")","(23,\\"2024-02-04 20:06:00+06\\")","(24,\\"2024-02-04 20:08:00+06\\")","(25,\\"2024-02-04 20:10:00+06\\")","(26,\\"2024-02-04 20:12:00+06\\")","(70,\\"2024-02-04 20:14:00+06\\")"}	from_buet	Ba-20-3066	t	monu67	nazmul	f	alamgir	t
2073	2024-02-04 23:30:00+06	3	evening	{"(17,\\"2024-02-04 23:30:00+06\\")","(18,\\"2024-02-04 23:45:00+06\\")","(19,\\"2024-02-04 23:48:00+06\\")","(20,\\"2024-02-04 23:50:00+06\\")","(21,\\"2024-02-04 23:52:00+06\\")","(22,\\"2024-02-04 23:54:00+06\\")","(23,\\"2024-02-04 23:56:00+06\\")","(24,\\"2024-02-04 23:58:00+06\\")","(25,\\"2024-02-04 00:00:00+06\\")","(26,\\"2024-02-04 00:02:00+06\\")","(70,\\"2024-02-04 00:04:00+06\\")"}	from_buet	Ba-20-3066	t	monu67	nazmul	f	alamgir	t
2074	2024-02-04 12:40:00+06	4	morning	{"(27,\\"2024-02-04 12:40:00+06\\")","(28,\\"2024-02-04 12:42:00+06\\")","(29,\\"2024-02-04 12:44:00+06\\")","(30,\\"2024-02-04 12:46:00+06\\")","(31,\\"2024-02-04 12:50:00+06\\")","(32,\\"2024-02-04 12:52:00+06\\")","(33,\\"2024-02-04 12:54:00+06\\")","(34,\\"2024-02-04 12:58:00+06\\")","(35,\\"2024-02-04 13:00:00+06\\")","(70,\\"2024-02-04 13:10:00+06\\")"}	to_buet	Ba-24-8518	t	shafiqul	nazmul	f	nasir81	t
2075	2024-02-04 19:40:00+06	4	afternoon	{"(27,\\"2024-02-04 19:40:00+06\\")","(28,\\"2024-02-04 19:50:00+06\\")","(29,\\"2024-02-04 19:52:00+06\\")","(30,\\"2024-02-04 19:54:00+06\\")","(31,\\"2024-02-04 19:56:00+06\\")","(32,\\"2024-02-04 19:58:00+06\\")","(33,\\"2024-02-04 20:00:00+06\\")","(34,\\"2024-02-04 20:02:00+06\\")","(35,\\"2024-02-04 20:04:00+06\\")","(70,\\"2024-02-04 20:06:00+06\\")"}	from_buet	Ba-24-8518	t	shafiqul	nazmul	f	nasir81	t
2076	2024-02-04 23:30:00+06	4	evening	{"(27,\\"2024-02-04 23:30:00+06\\")","(28,\\"2024-02-04 23:40:00+06\\")","(29,\\"2024-02-04 23:42:00+06\\")","(30,\\"2024-02-04 23:44:00+06\\")","(31,\\"2024-02-04 23:46:00+06\\")","(32,\\"2024-02-04 23:48:00+06\\")","(33,\\"2024-02-04 23:50:00+06\\")","(34,\\"2024-02-04 23:52:00+06\\")","(35,\\"2024-02-04 23:54:00+06\\")","(70,\\"2024-02-04 23:56:00+06\\")"}	from_buet	Ba-24-8518	t	shafiqul	nazmul	f	nasir81	t
2080	2024-02-04 12:40:00+06	6	morning	{"(41,\\"2024-02-04 12:40:00+06\\")","(42,\\"2024-02-04 12:42:00+06\\")","(43,\\"2024-02-04 12:45:00+06\\")","(44,\\"2024-02-04 12:47:00+06\\")","(45,\\"2024-02-04 12:49:00+06\\")","(46,\\"2024-02-04 12:51:00+06\\")","(47,\\"2024-02-04 12:52:00+06\\")","(48,\\"2024-02-04 12:53:00+06\\")","(49,\\"2024-02-04 12:54:00+06\\")","(70,\\"2024-02-04 13:10:00+06\\")"}	to_buet	Ba-12-8888	t	kamaluddin	nazmul	f	zahir53	t
2081	2024-02-04 19:40:00+06	6	afternoon	{"(41,\\"2024-02-04 19:40:00+06\\")","(42,\\"2024-02-04 19:56:00+06\\")","(43,\\"2024-02-04 19:58:00+06\\")","(44,\\"2024-02-04 20:00:00+06\\")","(45,\\"2024-02-04 20:02:00+06\\")","(46,\\"2024-02-04 20:04:00+06\\")","(47,\\"2024-02-04 20:06:00+06\\")","(48,\\"2024-02-04 20:08:00+06\\")","(49,\\"2024-02-04 20:10:00+06\\")","(70,\\"2024-02-04 20:12:00+06\\")"}	from_buet	Ba-12-8888	t	kamaluddin	nazmul	f	zahir53	t
2082	2024-02-04 23:30:00+06	6	evening	{"(41,\\"2024-02-04 23:30:00+06\\")","(42,\\"2024-02-04 23:46:00+06\\")","(43,\\"2024-02-04 23:48:00+06\\")","(44,\\"2024-02-04 23:50:00+06\\")","(45,\\"2024-02-04 23:52:00+06\\")","(46,\\"2024-02-04 23:54:00+06\\")","(47,\\"2024-02-04 23:56:00+06\\")","(48,\\"2024-02-04 23:58:00+06\\")","(49,\\"2024-02-04 00:00:00+06\\")","(70,\\"2024-02-04 00:02:00+06\\")"}	from_buet	Ba-12-8888	t	kamaluddin	nazmul	f	zahir53	t
2083	2024-02-04 12:40:00+06	7	morning	{"(50,\\"2024-02-04 12:40:00+06\\")","(51,\\"2024-02-04 12:42:00+06\\")","(52,\\"2024-02-04 12:43:00+06\\")","(53,\\"2024-02-04 12:46:00+06\\")","(54,\\"2024-02-04 12:47:00+06\\")","(55,\\"2024-02-04 12:48:00+06\\")","(56,\\"2024-02-04 12:50:00+06\\")","(57,\\"2024-02-04 12:52:00+06\\")","(58,\\"2024-02-04 12:53:00+06\\")","(59,\\"2024-02-04 12:54:00+06\\")","(60,\\"2024-02-04 12:56:00+06\\")","(61,\\"2024-02-04 12:58:00+06\\")","(62,\\"2024-02-04 13:00:00+06\\")","(63,\\"2024-02-04 13:02:00+06\\")","(70,\\"2024-02-04 13:00:00+06\\")"}	to_buet	Ba-19-0569	t	fazlu77	nazmul	f	siddiq2	t
2084	2024-02-04 19:40:00+06	7	afternoon	{"(50,\\"2024-02-04 19:40:00+06\\")","(51,\\"2024-02-04 19:48:00+06\\")","(52,\\"2024-02-04 19:50:00+06\\")","(53,\\"2024-02-04 19:52:00+06\\")","(54,\\"2024-02-04 19:54:00+06\\")","(55,\\"2024-02-04 19:56:00+06\\")","(56,\\"2024-02-04 19:58:00+06\\")","(57,\\"2024-02-04 20:00:00+06\\")","(58,\\"2024-02-04 20:02:00+06\\")","(59,\\"2024-02-04 20:04:00+06\\")","(60,\\"2024-02-04 20:06:00+06\\")","(61,\\"2024-02-04 20:08:00+06\\")","(62,\\"2024-02-04 20:10:00+06\\")","(63,\\"2024-02-04 20:12:00+06\\")","(70,\\"2024-02-04 20:14:00+06\\")"}	from_buet	Ba-19-0569	t	fazlu77	nazmul	f	siddiq2	t
2085	2024-02-04 23:30:00+06	7	evening	{"(50,\\"2024-02-04 23:30:00+06\\")","(51,\\"2024-02-04 23:38:00+06\\")","(52,\\"2024-02-04 23:40:00+06\\")","(53,\\"2024-02-04 23:42:00+06\\")","(54,\\"2024-02-04 23:44:00+06\\")","(55,\\"2024-02-04 23:46:00+06\\")","(56,\\"2024-02-04 23:48:00+06\\")","(57,\\"2024-02-04 23:50:00+06\\")","(58,\\"2024-02-04 23:52:00+06\\")","(59,\\"2024-02-04 23:54:00+06\\")","(60,\\"2024-02-04 23:56:00+06\\")","(61,\\"2024-02-04 23:58:00+06\\")","(62,\\"2024-02-04 00:00:00+06\\")","(63,\\"2024-02-04 00:02:00+06\\")","(70,\\"2024-02-04 00:04:00+06\\")"}	from_buet	Ba-19-0569	t	fazlu77	nazmul	f	siddiq2	t
2086	2024-02-04 12:15:00+06	1	morning	{"(1,\\"2024-02-04 12:15:00+06\\")","(2,\\"2024-02-04 12:18:00+06\\")","(3,\\"2024-02-04 12:20:00+06\\")","(4,\\"2024-02-04 12:23:00+06\\")","(5,\\"2024-02-04 12:26:00+06\\")","(6,\\"2024-02-04 12:29:00+06\\")","(7,\\"2024-02-04 12:49:00+06\\")","(8,\\"2024-02-04 12:51:00+06\\")","(9,\\"2024-02-04 12:53:00+06\\")","(10,\\"2024-02-04 12:55:00+06\\")","(11,\\"2024-02-04 12:58:00+06\\")","(70,\\"2024-02-04 13:05:00+06\\")"}	to_buet	Ba-77-7044	t	imranhashmi	nazmul	f	khairul	t
2087	2024-02-04 19:40:00+06	1	afternoon	{"(1,\\"2024-02-04 19:40:00+06\\")","(2,\\"2024-02-04 19:47:00+06\\")","(3,\\"2024-02-04 19:50:00+06\\")","(4,\\"2024-02-04 19:52:00+06\\")","(5,\\"2024-02-04 19:54:00+06\\")","(6,\\"2024-02-04 20:06:00+06\\")","(7,\\"2024-02-04 20:09:00+06\\")","(8,\\"2024-02-04 20:12:00+06\\")","(9,\\"2024-02-04 20:15:00+06\\")","(10,\\"2024-02-04 20:18:00+06\\")","(11,\\"2024-02-04 20:21:00+06\\")","(70,\\"2024-02-04 20:24:00+06\\")"}	from_buet	Ba-77-7044	t	imranhashmi	nazmul	f	khairul	t
2088	2024-02-04 23:30:00+06	1	evening	{"(1,\\"2024-02-04 23:30:00+06\\")","(2,\\"2024-02-04 23:37:00+06\\")","(3,\\"2024-02-04 23:40:00+06\\")","(4,\\"2024-02-04 23:42:00+06\\")","(5,\\"2024-02-04 23:44:00+06\\")","(6,\\"2024-02-04 23:56:00+06\\")","(7,\\"2024-02-04 23:59:00+06\\")","(8,\\"2024-02-04 00:02:00+06\\")","(9,\\"2024-02-04 00:05:00+06\\")","(10,\\"2024-02-04 00:08:00+06\\")","(11,\\"2024-02-04 00:11:00+06\\")","(70,\\"2024-02-04 00:14:00+06\\")"}	from_buet	Ba-77-7044	t	imranhashmi	nazmul	f	khairul	t
2089	2024-02-04 12:10:00+06	8	morning	{"(64,\\"2024-02-04 12:10:00+06\\")","(65,\\"2024-02-04 12:13:00+06\\")","(66,\\"2024-02-04 12:18:00+06\\")","(67,\\"2024-02-04 12:20:00+06\\")","(68,\\"2024-02-04 12:22:00+06\\")","(69,\\"2024-02-04 12:25:00+06\\")","(70,\\"2024-02-04 12:40:00+06\\")"}	to_buet	Ba-93-6087	t	sohel55	nazmul	f	reyazul	t
2090	2024-02-04 19:40:00+06	8	afternoon	{"(64,\\"2024-02-04 19:40:00+06\\")","(65,\\"2024-02-04 19:55:00+06\\")","(66,\\"2024-02-04 19:58:00+06\\")","(67,\\"2024-02-04 20:01:00+06\\")","(68,\\"2024-02-04 20:04:00+06\\")","(69,\\"2024-02-04 20:07:00+06\\")","(70,\\"2024-02-04 20:10:00+06\\")"}	from_buet	Ba-93-6087	t	sohel55	nazmul	f	reyazul	t
2091	2024-02-04 23:30:00+06	8	evening	{"(64,\\"2024-02-04 23:30:00+06\\")","(65,\\"2024-02-04 23:45:00+06\\")","(66,\\"2024-02-04 23:48:00+06\\")","(67,\\"2024-02-04 23:51:00+06\\")","(68,\\"2024-02-04 23:54:00+06\\")","(69,\\"2024-02-04 23:57:00+06\\")","(70,\\"2024-02-04 00:00:00+06\\")"}	from_buet	Ba-93-6087	t	sohel55	nazmul	f	reyazul	t
2092	2024-02-05 12:55:00+06	2	morning	{"(12,\\"2024-02-05 12:55:00+06\\")","(13,\\"2024-02-05 12:57:00+06\\")","(14,\\"2024-02-05 12:59:00+06\\")","(15,\\"2024-02-05 13:01:00+06\\")","(16,\\"2024-02-05 13:03:00+06\\")","(70,\\"2024-02-05 13:15:00+06\\")"}	to_buet	Ba-77-7044	t	nizam88	nazmul	f	farid99	t
2093	2024-02-05 19:40:00+06	2	afternoon	{"(12,\\"2024-02-05 19:40:00+06\\")","(13,\\"2024-02-05 19:52:00+06\\")","(14,\\"2024-02-05 19:54:00+06\\")","(15,\\"2024-02-05 19:57:00+06\\")","(16,\\"2024-02-05 20:00:00+06\\")","(70,\\"2024-02-05 20:03:00+06\\")"}	from_buet	Ba-77-7044	t	nizam88	nazmul	f	farid99	t
2094	2024-02-05 23:30:00+06	2	evening	{"(12,\\"2024-02-05 23:30:00+06\\")","(13,\\"2024-02-05 23:42:00+06\\")","(14,\\"2024-02-05 23:45:00+06\\")","(15,\\"2024-02-05 23:48:00+06\\")","(16,\\"2024-02-05 23:51:00+06\\")","(70,\\"2024-02-05 23:54:00+06\\")"}	from_buet	Ba-77-7044	t	nizam88	nazmul	f	farid99	t
2095	2024-02-05 12:40:00+06	3	morning	{"(17,\\"2024-02-05 12:40:00+06\\")","(18,\\"2024-02-05 12:42:00+06\\")","(19,\\"2024-02-05 12:44:00+06\\")","(20,\\"2024-02-05 12:46:00+06\\")","(21,\\"2024-02-05 12:48:00+06\\")","(22,\\"2024-02-05 12:50:00+06\\")","(23,\\"2024-02-05 12:52:00+06\\")","(24,\\"2024-02-05 12:54:00+06\\")","(25,\\"2024-02-05 12:57:00+06\\")","(26,\\"2024-02-05 13:00:00+06\\")","(70,\\"2024-02-05 13:15:00+06\\")"}	to_buet	Ba-20-3066	t	shahid88	nazmul	f	rashid56	t
2096	2024-02-05 19:40:00+06	3	afternoon	{"(17,\\"2024-02-05 19:40:00+06\\")","(18,\\"2024-02-05 19:55:00+06\\")","(19,\\"2024-02-05 19:58:00+06\\")","(20,\\"2024-02-05 20:00:00+06\\")","(21,\\"2024-02-05 20:02:00+06\\")","(22,\\"2024-02-05 20:04:00+06\\")","(23,\\"2024-02-05 20:06:00+06\\")","(24,\\"2024-02-05 20:08:00+06\\")","(25,\\"2024-02-05 20:10:00+06\\")","(26,\\"2024-02-05 20:12:00+06\\")","(70,\\"2024-02-05 20:14:00+06\\")"}	from_buet	Ba-20-3066	t	shahid88	nazmul	f	rashid56	t
2097	2024-02-05 23:30:00+06	3	evening	{"(17,\\"2024-02-05 23:30:00+06\\")","(18,\\"2024-02-05 23:45:00+06\\")","(19,\\"2024-02-05 23:48:00+06\\")","(20,\\"2024-02-05 23:50:00+06\\")","(21,\\"2024-02-05 23:52:00+06\\")","(22,\\"2024-02-05 23:54:00+06\\")","(23,\\"2024-02-05 23:56:00+06\\")","(24,\\"2024-02-05 23:58:00+06\\")","(25,\\"2024-02-05 00:00:00+06\\")","(26,\\"2024-02-05 00:02:00+06\\")","(70,\\"2024-02-05 00:04:00+06\\")"}	from_buet	Ba-20-3066	t	shahid88	nazmul	f	rashid56	t
2098	2024-02-05 12:40:00+06	4	morning	{"(27,\\"2024-02-05 12:40:00+06\\")","(28,\\"2024-02-05 12:42:00+06\\")","(29,\\"2024-02-05 12:44:00+06\\")","(30,\\"2024-02-05 12:46:00+06\\")","(31,\\"2024-02-05 12:50:00+06\\")","(32,\\"2024-02-05 12:52:00+06\\")","(33,\\"2024-02-05 12:54:00+06\\")","(34,\\"2024-02-05 12:58:00+06\\")","(35,\\"2024-02-05 13:00:00+06\\")","(70,\\"2024-02-05 13:10:00+06\\")"}	to_buet	Ba-36-1921	t	aminhaque	nazmul	f	alamgir	t
2099	2024-02-05 19:40:00+06	4	afternoon	{"(27,\\"2024-02-05 19:40:00+06\\")","(28,\\"2024-02-05 19:50:00+06\\")","(29,\\"2024-02-05 19:52:00+06\\")","(30,\\"2024-02-05 19:54:00+06\\")","(31,\\"2024-02-05 19:56:00+06\\")","(32,\\"2024-02-05 19:58:00+06\\")","(33,\\"2024-02-05 20:00:00+06\\")","(34,\\"2024-02-05 20:02:00+06\\")","(35,\\"2024-02-05 20:04:00+06\\")","(70,\\"2024-02-05 20:06:00+06\\")"}	from_buet	Ba-36-1921	t	aminhaque	nazmul	f	alamgir	t
2100	2024-02-05 23:30:00+06	4	evening	{"(27,\\"2024-02-05 23:30:00+06\\")","(28,\\"2024-02-05 23:40:00+06\\")","(29,\\"2024-02-05 23:42:00+06\\")","(30,\\"2024-02-05 23:44:00+06\\")","(31,\\"2024-02-05 23:46:00+06\\")","(32,\\"2024-02-05 23:48:00+06\\")","(33,\\"2024-02-05 23:50:00+06\\")","(34,\\"2024-02-05 23:52:00+06\\")","(35,\\"2024-02-05 23:54:00+06\\")","(70,\\"2024-02-05 23:56:00+06\\")"}	from_buet	Ba-36-1921	t	aminhaque	nazmul	f	alamgir	t
2101	2024-02-05 12:30:00+06	5	morning	{"(36,\\"2024-02-05 12:30:00+06\\")","(37,\\"2024-02-05 12:33:00+06\\")","(38,\\"2024-02-05 12:40:00+06\\")","(39,\\"2024-02-05 12:45:00+06\\")","(40,\\"2024-02-05 12:50:00+06\\")","(70,\\"2024-02-05 13:00:00+06\\")"}	to_buet	Ba-71-7930	t	monu67	nazmul	f	mahabhu	t
2102	2024-02-05 19:40:00+06	5	afternoon	{"(36,\\"2024-02-05 19:40:00+06\\")","(37,\\"2024-02-05 19:50:00+06\\")","(38,\\"2024-02-05 19:55:00+06\\")","(39,\\"2024-02-05 20:00:00+06\\")","(40,\\"2024-02-05 20:07:00+06\\")","(70,\\"2024-02-05 20:10:00+06\\")"}	from_buet	Ba-71-7930	t	monu67	nazmul	f	mahabhu	t
2103	2024-02-05 23:30:00+06	5	evening	{"(36,\\"2024-02-05 23:30:00+06\\")","(37,\\"2024-02-05 23:40:00+06\\")","(38,\\"2024-02-05 23:45:00+06\\")","(39,\\"2024-02-05 23:50:00+06\\")","(40,\\"2024-02-05 23:57:00+06\\")","(70,\\"2024-02-05 00:00:00+06\\")"}	from_buet	Ba-71-7930	t	monu67	nazmul	f	mahabhu	t
2104	2024-02-05 12:40:00+06	6	morning	{"(41,\\"2024-02-05 12:40:00+06\\")","(42,\\"2024-02-05 12:42:00+06\\")","(43,\\"2024-02-05 12:45:00+06\\")","(44,\\"2024-02-05 12:47:00+06\\")","(45,\\"2024-02-05 12:49:00+06\\")","(46,\\"2024-02-05 12:51:00+06\\")","(47,\\"2024-02-05 12:52:00+06\\")","(48,\\"2024-02-05 12:53:00+06\\")","(49,\\"2024-02-05 12:54:00+06\\")","(70,\\"2024-02-05 13:10:00+06\\")"}	to_buet	Ba-86-1841	t	nazrul6	nazmul	f	mahmud64	t
2105	2024-02-05 19:40:00+06	6	afternoon	{"(41,\\"2024-02-05 19:40:00+06\\")","(42,\\"2024-02-05 19:56:00+06\\")","(43,\\"2024-02-05 19:58:00+06\\")","(44,\\"2024-02-05 20:00:00+06\\")","(45,\\"2024-02-05 20:02:00+06\\")","(46,\\"2024-02-05 20:04:00+06\\")","(47,\\"2024-02-05 20:06:00+06\\")","(48,\\"2024-02-05 20:08:00+06\\")","(49,\\"2024-02-05 20:10:00+06\\")","(70,\\"2024-02-05 20:12:00+06\\")"}	from_buet	Ba-86-1841	t	nazrul6	nazmul	f	mahmud64	t
2106	2024-02-05 23:30:00+06	6	evening	{"(41,\\"2024-02-05 23:30:00+06\\")","(42,\\"2024-02-05 23:46:00+06\\")","(43,\\"2024-02-05 23:48:00+06\\")","(44,\\"2024-02-05 23:50:00+06\\")","(45,\\"2024-02-05 23:52:00+06\\")","(46,\\"2024-02-05 23:54:00+06\\")","(47,\\"2024-02-05 23:56:00+06\\")","(48,\\"2024-02-05 23:58:00+06\\")","(49,\\"2024-02-05 00:00:00+06\\")","(70,\\"2024-02-05 00:02:00+06\\")"}	from_buet	Ba-86-1841	t	nazrul6	nazmul	f	mahmud64	t
2110	2024-02-05 12:15:00+06	1	morning	{"(1,\\"2024-02-05 12:15:00+06\\")","(2,\\"2024-02-05 12:18:00+06\\")","(3,\\"2024-02-05 12:20:00+06\\")","(4,\\"2024-02-05 12:23:00+06\\")","(5,\\"2024-02-05 12:26:00+06\\")","(6,\\"2024-02-05 12:29:00+06\\")","(7,\\"2024-02-05 12:49:00+06\\")","(8,\\"2024-02-05 12:51:00+06\\")","(9,\\"2024-02-05 12:53:00+06\\")","(10,\\"2024-02-05 12:55:00+06\\")","(11,\\"2024-02-05 12:58:00+06\\")","(70,\\"2024-02-05 13:05:00+06\\")"}	to_buet	BA-01-2345	t	masud84	nazmul	f	mahbub777	t
2111	2024-02-05 19:40:00+06	1	afternoon	{"(1,\\"2024-02-05 19:40:00+06\\")","(2,\\"2024-02-05 19:47:00+06\\")","(3,\\"2024-02-05 19:50:00+06\\")","(4,\\"2024-02-05 19:52:00+06\\")","(5,\\"2024-02-05 19:54:00+06\\")","(6,\\"2024-02-05 20:06:00+06\\")","(7,\\"2024-02-05 20:09:00+06\\")","(8,\\"2024-02-05 20:12:00+06\\")","(9,\\"2024-02-05 20:15:00+06\\")","(10,\\"2024-02-05 20:18:00+06\\")","(11,\\"2024-02-05 20:21:00+06\\")","(70,\\"2024-02-05 20:24:00+06\\")"}	from_buet	BA-01-2345	t	masud84	nazmul	f	mahbub777	t
2112	2024-02-05 23:30:00+06	1	evening	{"(1,\\"2024-02-05 23:30:00+06\\")","(2,\\"2024-02-05 23:37:00+06\\")","(3,\\"2024-02-05 23:40:00+06\\")","(4,\\"2024-02-05 23:42:00+06\\")","(5,\\"2024-02-05 23:44:00+06\\")","(6,\\"2024-02-05 23:56:00+06\\")","(7,\\"2024-02-05 23:59:00+06\\")","(8,\\"2024-02-05 00:02:00+06\\")","(9,\\"2024-02-05 00:05:00+06\\")","(10,\\"2024-02-05 00:08:00+06\\")","(11,\\"2024-02-05 00:11:00+06\\")","(70,\\"2024-02-05 00:14:00+06\\")"}	from_buet	BA-01-2345	t	masud84	nazmul	f	mahbub777	t
2113	2024-02-05 12:10:00+06	8	morning	{"(64,\\"2024-02-05 12:10:00+06\\")","(65,\\"2024-02-05 12:13:00+06\\")","(66,\\"2024-02-05 12:18:00+06\\")","(67,\\"2024-02-05 12:20:00+06\\")","(68,\\"2024-02-05 12:22:00+06\\")","(69,\\"2024-02-05 12:25:00+06\\")","(70,\\"2024-02-05 12:40:00+06\\")"}	to_buet	Ba-19-0569	t	rashed3	nazmul	f	nasir81	t
2114	2024-02-05 19:40:00+06	8	afternoon	{"(64,\\"2024-02-05 19:40:00+06\\")","(65,\\"2024-02-05 19:55:00+06\\")","(66,\\"2024-02-05 19:58:00+06\\")","(67,\\"2024-02-05 20:01:00+06\\")","(68,\\"2024-02-05 20:04:00+06\\")","(69,\\"2024-02-05 20:07:00+06\\")","(70,\\"2024-02-05 20:10:00+06\\")"}	from_buet	Ba-19-0569	t	rashed3	nazmul	f	nasir81	t
2115	2024-02-05 23:30:00+06	8	evening	{"(64,\\"2024-02-05 23:30:00+06\\")","(65,\\"2024-02-05 23:45:00+06\\")","(66,\\"2024-02-05 23:48:00+06\\")","(67,\\"2024-02-05 23:51:00+06\\")","(68,\\"2024-02-05 23:54:00+06\\")","(69,\\"2024-02-05 23:57:00+06\\")","(70,\\"2024-02-05 00:00:00+06\\")"}	from_buet	Ba-19-0569	t	rashed3	nazmul	f	nasir81	t
2116	2024-02-06 12:55:00+06	2	morning	{"(12,\\"2024-02-06 12:55:00+06\\")","(13,\\"2024-02-06 12:57:00+06\\")","(14,\\"2024-02-06 12:59:00+06\\")","(15,\\"2024-02-06 13:01:00+06\\")","(16,\\"2024-02-06 13:03:00+06\\")","(70,\\"2024-02-06 13:15:00+06\\")"}	to_buet	Ba-77-7044	t	jahangir	nazmul	f	sharif86r	t
2117	2024-02-06 19:40:00+06	2	afternoon	{"(12,\\"2024-02-06 19:40:00+06\\")","(13,\\"2024-02-06 19:52:00+06\\")","(14,\\"2024-02-06 19:54:00+06\\")","(15,\\"2024-02-06 19:57:00+06\\")","(16,\\"2024-02-06 20:00:00+06\\")","(70,\\"2024-02-06 20:03:00+06\\")"}	from_buet	Ba-77-7044	t	jahangir	nazmul	f	sharif86r	t
2118	2024-02-06 23:30:00+06	2	evening	{"(12,\\"2024-02-06 23:30:00+06\\")","(13,\\"2024-02-06 23:42:00+06\\")","(14,\\"2024-02-06 23:45:00+06\\")","(15,\\"2024-02-06 23:48:00+06\\")","(16,\\"2024-02-06 23:51:00+06\\")","(70,\\"2024-02-06 23:54:00+06\\")"}	from_buet	Ba-77-7044	t	jahangir	nazmul	f	sharif86r	t
2119	2024-02-06 12:40:00+06	3	morning	{"(17,\\"2024-02-06 12:40:00+06\\")","(18,\\"2024-02-06 12:42:00+06\\")","(19,\\"2024-02-06 12:44:00+06\\")","(20,\\"2024-02-06 12:46:00+06\\")","(21,\\"2024-02-06 12:48:00+06\\")","(22,\\"2024-02-06 12:50:00+06\\")","(23,\\"2024-02-06 12:52:00+06\\")","(24,\\"2024-02-06 12:54:00+06\\")","(25,\\"2024-02-06 12:57:00+06\\")","(26,\\"2024-02-06 13:00:00+06\\")","(70,\\"2024-02-06 13:15:00+06\\")"}	to_buet	Ba-83-8014	t	abdulkarim6	nazmul	f	siddiq2	t
2120	2024-02-06 19:40:00+06	3	afternoon	{"(17,\\"2024-02-06 19:40:00+06\\")","(18,\\"2024-02-06 19:55:00+06\\")","(19,\\"2024-02-06 19:58:00+06\\")","(20,\\"2024-02-06 20:00:00+06\\")","(21,\\"2024-02-06 20:02:00+06\\")","(22,\\"2024-02-06 20:04:00+06\\")","(23,\\"2024-02-06 20:06:00+06\\")","(24,\\"2024-02-06 20:08:00+06\\")","(25,\\"2024-02-06 20:10:00+06\\")","(26,\\"2024-02-06 20:12:00+06\\")","(70,\\"2024-02-06 20:14:00+06\\")"}	from_buet	Ba-83-8014	t	abdulkarim6	nazmul	f	siddiq2	t
2121	2024-02-06 23:30:00+06	3	evening	{"(17,\\"2024-02-06 23:30:00+06\\")","(18,\\"2024-02-06 23:45:00+06\\")","(19,\\"2024-02-06 23:48:00+06\\")","(20,\\"2024-02-06 23:50:00+06\\")","(21,\\"2024-02-06 23:52:00+06\\")","(22,\\"2024-02-06 23:54:00+06\\")","(23,\\"2024-02-06 23:56:00+06\\")","(24,\\"2024-02-06 23:58:00+06\\")","(25,\\"2024-02-06 00:00:00+06\\")","(26,\\"2024-02-06 00:02:00+06\\")","(70,\\"2024-02-06 00:04:00+06\\")"}	from_buet	Ba-83-8014	t	abdulkarim6	nazmul	f	siddiq2	t
2122	2024-02-06 12:40:00+06	4	morning	{"(27,\\"2024-02-06 12:40:00+06\\")","(28,\\"2024-02-06 12:42:00+06\\")","(29,\\"2024-02-06 12:44:00+06\\")","(30,\\"2024-02-06 12:46:00+06\\")","(31,\\"2024-02-06 12:50:00+06\\")","(32,\\"2024-02-06 12:52:00+06\\")","(33,\\"2024-02-06 12:54:00+06\\")","(34,\\"2024-02-06 12:58:00+06\\")","(35,\\"2024-02-06 13:00:00+06\\")","(70,\\"2024-02-06 13:10:00+06\\")"}	to_buet	Ba-17-3886	t	masud84	nazmul	f	mahbub777	t
2123	2024-02-06 19:40:00+06	4	afternoon	{"(27,\\"2024-02-06 19:40:00+06\\")","(28,\\"2024-02-06 19:50:00+06\\")","(29,\\"2024-02-06 19:52:00+06\\")","(30,\\"2024-02-06 19:54:00+06\\")","(31,\\"2024-02-06 19:56:00+06\\")","(32,\\"2024-02-06 19:58:00+06\\")","(33,\\"2024-02-06 20:00:00+06\\")","(34,\\"2024-02-06 20:02:00+06\\")","(35,\\"2024-02-06 20:04:00+06\\")","(70,\\"2024-02-06 20:06:00+06\\")"}	from_buet	Ba-17-3886	t	masud84	nazmul	f	mahbub777	t
2124	2024-02-06 23:30:00+06	4	evening	{"(27,\\"2024-02-06 23:30:00+06\\")","(28,\\"2024-02-06 23:40:00+06\\")","(29,\\"2024-02-06 23:42:00+06\\")","(30,\\"2024-02-06 23:44:00+06\\")","(31,\\"2024-02-06 23:46:00+06\\")","(32,\\"2024-02-06 23:48:00+06\\")","(33,\\"2024-02-06 23:50:00+06\\")","(34,\\"2024-02-06 23:52:00+06\\")","(35,\\"2024-02-06 23:54:00+06\\")","(70,\\"2024-02-06 23:56:00+06\\")"}	from_buet	Ba-17-3886	t	masud84	nazmul	f	mahbub777	t
2125	2024-02-06 12:30:00+06	5	morning	{"(36,\\"2024-02-06 12:30:00+06\\")","(37,\\"2024-02-06 12:33:00+06\\")","(38,\\"2024-02-06 12:40:00+06\\")","(39,\\"2024-02-06 12:45:00+06\\")","(40,\\"2024-02-06 12:50:00+06\\")","(70,\\"2024-02-06 13:00:00+06\\")"}	to_buet	Ba-48-5757	t	rashed3	nazmul	f	mahmud64	t
2126	2024-02-06 19:40:00+06	5	afternoon	{"(36,\\"2024-02-06 19:40:00+06\\")","(37,\\"2024-02-06 19:50:00+06\\")","(38,\\"2024-02-06 19:55:00+06\\")","(39,\\"2024-02-06 20:00:00+06\\")","(40,\\"2024-02-06 20:07:00+06\\")","(70,\\"2024-02-06 20:10:00+06\\")"}	from_buet	Ba-48-5757	t	rashed3	nazmul	f	mahmud64	t
2128	2024-02-06 12:40:00+06	6	morning	{"(41,\\"2024-02-06 12:40:00+06\\")","(42,\\"2024-02-06 12:42:00+06\\")","(43,\\"2024-02-06 12:45:00+06\\")","(44,\\"2024-02-06 12:47:00+06\\")","(45,\\"2024-02-06 12:49:00+06\\")","(46,\\"2024-02-06 12:51:00+06\\")","(47,\\"2024-02-06 12:52:00+06\\")","(48,\\"2024-02-06 12:53:00+06\\")","(49,\\"2024-02-06 12:54:00+06\\")","(70,\\"2024-02-06 13:10:00+06\\")"}	to_buet	Ba-46-1334	t	sohel55	nazmul	f	khairul	t
2129	2024-02-06 19:40:00+06	6	afternoon	{"(41,\\"2024-02-06 19:40:00+06\\")","(42,\\"2024-02-06 19:56:00+06\\")","(43,\\"2024-02-06 19:58:00+06\\")","(44,\\"2024-02-06 20:00:00+06\\")","(45,\\"2024-02-06 20:02:00+06\\")","(46,\\"2024-02-06 20:04:00+06\\")","(47,\\"2024-02-06 20:06:00+06\\")","(48,\\"2024-02-06 20:08:00+06\\")","(49,\\"2024-02-06 20:10:00+06\\")","(70,\\"2024-02-06 20:12:00+06\\")"}	from_buet	Ba-46-1334	t	sohel55	nazmul	f	khairul	t
2130	2024-02-06 23:30:00+06	6	evening	{"(41,\\"2024-02-06 23:30:00+06\\")","(42,\\"2024-02-06 23:46:00+06\\")","(43,\\"2024-02-06 23:48:00+06\\")","(44,\\"2024-02-06 23:50:00+06\\")","(45,\\"2024-02-06 23:52:00+06\\")","(46,\\"2024-02-06 23:54:00+06\\")","(47,\\"2024-02-06 23:56:00+06\\")","(48,\\"2024-02-06 23:58:00+06\\")","(49,\\"2024-02-06 00:00:00+06\\")","(70,\\"2024-02-06 00:02:00+06\\")"}	from_buet	Ba-46-1334	t	sohel55	nazmul	f	khairul	t
2134	2024-02-06 12:15:00+06	1	morning	{"(1,\\"2024-02-06 12:15:00+06\\")","(2,\\"2024-02-06 12:18:00+06\\")","(3,\\"2024-02-06 12:20:00+06\\")","(4,\\"2024-02-06 12:23:00+06\\")","(5,\\"2024-02-06 12:26:00+06\\")","(6,\\"2024-02-06 12:29:00+06\\")","(7,\\"2024-02-06 12:49:00+06\\")","(8,\\"2024-02-06 12:51:00+06\\")","(9,\\"2024-02-06 12:53:00+06\\")","(10,\\"2024-02-06 12:55:00+06\\")","(11,\\"2024-02-06 12:58:00+06\\")","(70,\\"2024-02-06 13:05:00+06\\")"}	to_buet	Ba-22-4326	t	nazrul6	nazmul	f	ASADUZZAMAN	t
2135	2024-02-06 19:40:00+06	1	afternoon	{"(1,\\"2024-02-06 19:40:00+06\\")","(2,\\"2024-02-06 19:47:00+06\\")","(3,\\"2024-02-06 19:50:00+06\\")","(4,\\"2024-02-06 19:52:00+06\\")","(5,\\"2024-02-06 19:54:00+06\\")","(6,\\"2024-02-06 20:06:00+06\\")","(7,\\"2024-02-06 20:09:00+06\\")","(8,\\"2024-02-06 20:12:00+06\\")","(9,\\"2024-02-06 20:15:00+06\\")","(10,\\"2024-02-06 20:18:00+06\\")","(11,\\"2024-02-06 20:21:00+06\\")","(70,\\"2024-02-06 20:24:00+06\\")"}	from_buet	Ba-22-4326	t	nazrul6	nazmul	f	ASADUZZAMAN	t
2136	2024-02-06 23:30:00+06	1	evening	{"(1,\\"2024-02-06 23:30:00+06\\")","(2,\\"2024-02-06 23:37:00+06\\")","(3,\\"2024-02-06 23:40:00+06\\")","(4,\\"2024-02-06 23:42:00+06\\")","(5,\\"2024-02-06 23:44:00+06\\")","(6,\\"2024-02-06 23:56:00+06\\")","(7,\\"2024-02-06 23:59:00+06\\")","(8,\\"2024-02-06 00:02:00+06\\")","(9,\\"2024-02-06 00:05:00+06\\")","(10,\\"2024-02-06 00:08:00+06\\")","(11,\\"2024-02-06 00:11:00+06\\")","(70,\\"2024-02-06 00:14:00+06\\")"}	from_buet	Ba-22-4326	t	nazrul6	nazmul	f	ASADUZZAMAN	t
2138	2024-02-06 19:40:00+06	8	afternoon	{"(64,\\"2024-02-06 19:40:00+06\\")","(65,\\"2024-02-06 19:55:00+06\\")","(66,\\"2024-02-06 19:58:00+06\\")","(67,\\"2024-02-06 20:01:00+06\\")","(68,\\"2024-02-06 20:04:00+06\\")","(69,\\"2024-02-06 20:07:00+06\\")","(70,\\"2024-02-06 20:10:00+06\\")"}	from_buet	Ba-36-1921	t	rafiqul	nazmul	f	rashid56	t
2139	2024-02-06 23:30:00+06	8	evening	{"(64,\\"2024-02-06 23:30:00+06\\")","(65,\\"2024-02-06 23:45:00+06\\")","(66,\\"2024-02-06 23:48:00+06\\")","(67,\\"2024-02-06 23:51:00+06\\")","(68,\\"2024-02-06 23:54:00+06\\")","(69,\\"2024-02-06 23:57:00+06\\")","(70,\\"2024-02-06 00:00:00+06\\")"}	from_buet	Ba-36-1921	t	rafiqul	nazmul	f	rashid56	t
2140	2024-02-07 12:55:00+06	2	morning	{"(12,\\"2024-02-07 12:55:00+06\\")","(13,\\"2024-02-07 12:57:00+06\\")","(14,\\"2024-02-07 12:59:00+06\\")","(15,\\"2024-02-07 13:01:00+06\\")","(16,\\"2024-02-07 13:03:00+06\\")","(70,\\"2024-02-07 13:15:00+06\\")"}	to_buet	Ba-17-2081	t	monu67	nazmul	f	mahbub777	t
2141	2024-02-07 19:40:00+06	2	afternoon	{"(12,\\"2024-02-07 19:40:00+06\\")","(13,\\"2024-02-07 19:52:00+06\\")","(14,\\"2024-02-07 19:54:00+06\\")","(15,\\"2024-02-07 19:57:00+06\\")","(16,\\"2024-02-07 20:00:00+06\\")","(70,\\"2024-02-07 20:03:00+06\\")"}	from_buet	Ba-17-2081	t	monu67	nazmul	f	mahbub777	t
2142	2024-02-07 23:30:00+06	2	evening	{"(12,\\"2024-02-07 23:30:00+06\\")","(13,\\"2024-02-07 23:42:00+06\\")","(14,\\"2024-02-07 23:45:00+06\\")","(15,\\"2024-02-07 23:48:00+06\\")","(16,\\"2024-02-07 23:51:00+06\\")","(70,\\"2024-02-07 23:54:00+06\\")"}	from_buet	Ba-17-2081	t	monu67	nazmul	f	mahbub777	t
2143	2024-02-07 12:40:00+06	3	morning	{"(17,\\"2024-02-07 12:40:00+06\\")","(18,\\"2024-02-07 12:42:00+06\\")","(19,\\"2024-02-07 12:44:00+06\\")","(20,\\"2024-02-07 12:46:00+06\\")","(21,\\"2024-02-07 12:48:00+06\\")","(22,\\"2024-02-07 12:50:00+06\\")","(23,\\"2024-02-07 12:52:00+06\\")","(24,\\"2024-02-07 12:54:00+06\\")","(25,\\"2024-02-07 12:57:00+06\\")","(26,\\"2024-02-07 13:00:00+06\\")","(70,\\"2024-02-07 13:15:00+06\\")"}	to_buet	Ba-48-5757	t	sohel55	nazmul	f	ASADUZZAMAN	t
2144	2024-02-07 19:40:00+06	3	afternoon	{"(17,\\"2024-02-07 19:40:00+06\\")","(18,\\"2024-02-07 19:55:00+06\\")","(19,\\"2024-02-07 19:58:00+06\\")","(20,\\"2024-02-07 20:00:00+06\\")","(21,\\"2024-02-07 20:02:00+06\\")","(22,\\"2024-02-07 20:04:00+06\\")","(23,\\"2024-02-07 20:06:00+06\\")","(24,\\"2024-02-07 20:08:00+06\\")","(25,\\"2024-02-07 20:10:00+06\\")","(26,\\"2024-02-07 20:12:00+06\\")","(70,\\"2024-02-07 20:14:00+06\\")"}	from_buet	Ba-48-5757	t	sohel55	nazmul	f	ASADUZZAMAN	t
2145	2024-02-07 23:30:00+06	3	evening	{"(17,\\"2024-02-07 23:30:00+06\\")","(18,\\"2024-02-07 23:45:00+06\\")","(19,\\"2024-02-07 23:48:00+06\\")","(20,\\"2024-02-07 23:50:00+06\\")","(21,\\"2024-02-07 23:52:00+06\\")","(22,\\"2024-02-07 23:54:00+06\\")","(23,\\"2024-02-07 23:56:00+06\\")","(24,\\"2024-02-07 23:58:00+06\\")","(25,\\"2024-02-07 00:00:00+06\\")","(26,\\"2024-02-07 00:02:00+06\\")","(70,\\"2024-02-07 00:04:00+06\\")"}	from_buet	Ba-48-5757	t	sohel55	nazmul	f	ASADUZZAMAN	t
2146	2024-02-07 12:40:00+06	4	morning	{"(27,\\"2024-02-07 12:40:00+06\\")","(28,\\"2024-02-07 12:42:00+06\\")","(29,\\"2024-02-07 12:44:00+06\\")","(30,\\"2024-02-07 12:46:00+06\\")","(31,\\"2024-02-07 12:50:00+06\\")","(32,\\"2024-02-07 12:52:00+06\\")","(33,\\"2024-02-07 12:54:00+06\\")","(34,\\"2024-02-07 12:58:00+06\\")","(35,\\"2024-02-07 13:00:00+06\\")","(70,\\"2024-02-07 13:10:00+06\\")"}	to_buet	Ba-93-6087	t	rahmatullah	nazmul	f	reyazul	t
2147	2024-02-07 19:40:00+06	4	afternoon	{"(27,\\"2024-02-07 19:40:00+06\\")","(28,\\"2024-02-07 19:50:00+06\\")","(29,\\"2024-02-07 19:52:00+06\\")","(30,\\"2024-02-07 19:54:00+06\\")","(31,\\"2024-02-07 19:56:00+06\\")","(32,\\"2024-02-07 19:58:00+06\\")","(33,\\"2024-02-07 20:00:00+06\\")","(34,\\"2024-02-07 20:02:00+06\\")","(35,\\"2024-02-07 20:04:00+06\\")","(70,\\"2024-02-07 20:06:00+06\\")"}	from_buet	Ba-93-6087	t	rahmatullah	nazmul	f	reyazul	t
2148	2024-02-07 23:30:00+06	4	evening	{"(27,\\"2024-02-07 23:30:00+06\\")","(28,\\"2024-02-07 23:40:00+06\\")","(29,\\"2024-02-07 23:42:00+06\\")","(30,\\"2024-02-07 23:44:00+06\\")","(31,\\"2024-02-07 23:46:00+06\\")","(32,\\"2024-02-07 23:48:00+06\\")","(33,\\"2024-02-07 23:50:00+06\\")","(34,\\"2024-02-07 23:52:00+06\\")","(35,\\"2024-02-07 23:54:00+06\\")","(70,\\"2024-02-07 23:56:00+06\\")"}	from_buet	Ba-93-6087	t	rahmatullah	nazmul	f	reyazul	t
2151	2024-02-07 23:30:00+06	5	evening	{"(36,\\"2024-02-07 23:30:00+06\\")","(37,\\"2024-02-07 23:40:00+06\\")","(38,\\"2024-02-07 23:45:00+06\\")","(39,\\"2024-02-07 23:50:00+06\\")","(40,\\"2024-02-07 23:57:00+06\\")","(70,\\"2024-02-07 00:00:00+06\\")"}	from_buet	Ba-35-1461	t	arif43	nazmul	f	khairul	t
2152	2024-02-07 12:40:00+06	6	morning	{"(41,\\"2024-02-07 12:40:00+06\\")","(42,\\"2024-02-07 12:42:00+06\\")","(43,\\"2024-02-07 12:45:00+06\\")","(44,\\"2024-02-07 12:47:00+06\\")","(45,\\"2024-02-07 12:49:00+06\\")","(46,\\"2024-02-07 12:51:00+06\\")","(47,\\"2024-02-07 12:52:00+06\\")","(48,\\"2024-02-07 12:53:00+06\\")","(49,\\"2024-02-07 12:54:00+06\\")","(70,\\"2024-02-07 13:10:00+06\\")"}	to_buet	Ba-86-1841	t	altaf78	nazmul	f	abdulbari4	t
2153	2024-02-07 19:40:00+06	6	afternoon	{"(41,\\"2024-02-07 19:40:00+06\\")","(42,\\"2024-02-07 19:56:00+06\\")","(43,\\"2024-02-07 19:58:00+06\\")","(44,\\"2024-02-07 20:00:00+06\\")","(45,\\"2024-02-07 20:02:00+06\\")","(46,\\"2024-02-07 20:04:00+06\\")","(47,\\"2024-02-07 20:06:00+06\\")","(48,\\"2024-02-07 20:08:00+06\\")","(49,\\"2024-02-07 20:10:00+06\\")","(70,\\"2024-02-07 20:12:00+06\\")"}	from_buet	Ba-86-1841	t	altaf78	nazmul	f	abdulbari4	t
2154	2024-02-07 23:30:00+06	6	evening	{"(41,\\"2024-02-07 23:30:00+06\\")","(42,\\"2024-02-07 23:46:00+06\\")","(43,\\"2024-02-07 23:48:00+06\\")","(44,\\"2024-02-07 23:50:00+06\\")","(45,\\"2024-02-07 23:52:00+06\\")","(46,\\"2024-02-07 23:54:00+06\\")","(47,\\"2024-02-07 23:56:00+06\\")","(48,\\"2024-02-07 23:58:00+06\\")","(49,\\"2024-02-07 00:00:00+06\\")","(70,\\"2024-02-07 00:02:00+06\\")"}	from_buet	Ba-86-1841	t	altaf78	nazmul	f	abdulbari4	t
2155	2024-02-07 12:40:00+06	7	morning	{"(50,\\"2024-02-07 12:40:00+06\\")","(51,\\"2024-02-07 12:42:00+06\\")","(52,\\"2024-02-07 12:43:00+06\\")","(53,\\"2024-02-07 12:46:00+06\\")","(54,\\"2024-02-07 12:47:00+06\\")","(55,\\"2024-02-07 12:48:00+06\\")","(56,\\"2024-02-07 12:50:00+06\\")","(57,\\"2024-02-07 12:52:00+06\\")","(58,\\"2024-02-07 12:53:00+06\\")","(59,\\"2024-02-07 12:54:00+06\\")","(60,\\"2024-02-07 12:56:00+06\\")","(61,\\"2024-02-07 12:58:00+06\\")","(62,\\"2024-02-07 13:00:00+06\\")","(63,\\"2024-02-07 13:02:00+06\\")","(70,\\"2024-02-07 13:00:00+06\\")"}	to_buet	Ba-85-4722	t	rashed3	nazmul	f	alamgir	t
2156	2024-02-07 19:40:00+06	7	afternoon	{"(50,\\"2024-02-07 19:40:00+06\\")","(51,\\"2024-02-07 19:48:00+06\\")","(52,\\"2024-02-07 19:50:00+06\\")","(53,\\"2024-02-07 19:52:00+06\\")","(54,\\"2024-02-07 19:54:00+06\\")","(55,\\"2024-02-07 19:56:00+06\\")","(56,\\"2024-02-07 19:58:00+06\\")","(57,\\"2024-02-07 20:00:00+06\\")","(58,\\"2024-02-07 20:02:00+06\\")","(59,\\"2024-02-07 20:04:00+06\\")","(60,\\"2024-02-07 20:06:00+06\\")","(61,\\"2024-02-07 20:08:00+06\\")","(62,\\"2024-02-07 20:10:00+06\\")","(63,\\"2024-02-07 20:12:00+06\\")","(70,\\"2024-02-07 20:14:00+06\\")"}	from_buet	Ba-85-4722	t	rashed3	nazmul	f	alamgir	t
2157	2024-02-07 23:30:00+06	7	evening	{"(50,\\"2024-02-07 23:30:00+06\\")","(51,\\"2024-02-07 23:38:00+06\\")","(52,\\"2024-02-07 23:40:00+06\\")","(53,\\"2024-02-07 23:42:00+06\\")","(54,\\"2024-02-07 23:44:00+06\\")","(55,\\"2024-02-07 23:46:00+06\\")","(56,\\"2024-02-07 23:48:00+06\\")","(57,\\"2024-02-07 23:50:00+06\\")","(58,\\"2024-02-07 23:52:00+06\\")","(59,\\"2024-02-07 23:54:00+06\\")","(60,\\"2024-02-07 23:56:00+06\\")","(61,\\"2024-02-07 23:58:00+06\\")","(62,\\"2024-02-07 00:00:00+06\\")","(63,\\"2024-02-07 00:02:00+06\\")","(70,\\"2024-02-07 00:04:00+06\\")"}	from_buet	Ba-85-4722	t	rashed3	nazmul	f	alamgir	t
2158	2024-02-07 12:15:00+06	1	morning	{"(1,\\"2024-02-07 12:15:00+06\\")","(2,\\"2024-02-07 12:18:00+06\\")","(3,\\"2024-02-07 12:20:00+06\\")","(4,\\"2024-02-07 12:23:00+06\\")","(5,\\"2024-02-07 12:26:00+06\\")","(6,\\"2024-02-07 12:29:00+06\\")","(7,\\"2024-02-07 12:49:00+06\\")","(8,\\"2024-02-07 12:51:00+06\\")","(9,\\"2024-02-07 12:53:00+06\\")","(10,\\"2024-02-07 12:55:00+06\\")","(11,\\"2024-02-07 12:58:00+06\\")","(70,\\"2024-02-07 13:05:00+06\\")"}	to_buet	Ba-69-8288	t	shafiqul	nazmul	f	mahmud64	t
2159	2024-02-07 19:40:00+06	1	afternoon	{"(1,\\"2024-02-07 19:40:00+06\\")","(2,\\"2024-02-07 19:47:00+06\\")","(3,\\"2024-02-07 19:50:00+06\\")","(4,\\"2024-02-07 19:52:00+06\\")","(5,\\"2024-02-07 19:54:00+06\\")","(6,\\"2024-02-07 20:06:00+06\\")","(7,\\"2024-02-07 20:09:00+06\\")","(8,\\"2024-02-07 20:12:00+06\\")","(9,\\"2024-02-07 20:15:00+06\\")","(10,\\"2024-02-07 20:18:00+06\\")","(11,\\"2024-02-07 20:21:00+06\\")","(70,\\"2024-02-07 20:24:00+06\\")"}	from_buet	Ba-69-8288	t	shafiqul	nazmul	f	mahmud64	t
2160	2024-02-07 23:30:00+06	1	evening	{"(1,\\"2024-02-07 23:30:00+06\\")","(2,\\"2024-02-07 23:37:00+06\\")","(3,\\"2024-02-07 23:40:00+06\\")","(4,\\"2024-02-07 23:42:00+06\\")","(5,\\"2024-02-07 23:44:00+06\\")","(6,\\"2024-02-07 23:56:00+06\\")","(7,\\"2024-02-07 23:59:00+06\\")","(8,\\"2024-02-07 00:02:00+06\\")","(9,\\"2024-02-07 00:05:00+06\\")","(10,\\"2024-02-07 00:08:00+06\\")","(11,\\"2024-02-07 00:11:00+06\\")","(70,\\"2024-02-07 00:14:00+06\\")"}	from_buet	Ba-69-8288	t	shafiqul	nazmul	f	mahmud64	t
2167	2024-02-10 12:40:00+06	3	morning	{"(17,\\"2024-02-10 12:40:00+06\\")","(18,\\"2024-02-10 12:42:00+06\\")","(19,\\"2024-02-10 12:44:00+06\\")","(20,\\"2024-02-10 12:46:00+06\\")","(21,\\"2024-02-10 12:48:00+06\\")","(22,\\"2024-02-10 12:50:00+06\\")","(23,\\"2024-02-10 12:52:00+06\\")","(24,\\"2024-02-10 12:54:00+06\\")","(25,\\"2024-02-10 12:57:00+06\\")","(26,\\"2024-02-10 13:00:00+06\\")","(70,\\"2024-02-10 13:15:00+06\\")"}	to_buet	Ba-86-1841	t	abdulkarim6	nazmul	f	nasir81	t
2168	2024-02-10 19:40:00+06	3	afternoon	{"(17,\\"2024-02-10 19:40:00+06\\")","(18,\\"2024-02-10 19:55:00+06\\")","(19,\\"2024-02-10 19:58:00+06\\")","(20,\\"2024-02-10 20:00:00+06\\")","(21,\\"2024-02-10 20:02:00+06\\")","(22,\\"2024-02-10 20:04:00+06\\")","(23,\\"2024-02-10 20:06:00+06\\")","(24,\\"2024-02-10 20:08:00+06\\")","(25,\\"2024-02-10 20:10:00+06\\")","(26,\\"2024-02-10 20:12:00+06\\")","(70,\\"2024-02-10 20:14:00+06\\")"}	from_buet	Ba-86-1841	t	abdulkarim6	nazmul	f	nasir81	t
2169	2024-02-10 23:30:00+06	3	evening	{"(17,\\"2024-02-10 23:30:00+06\\")","(18,\\"2024-02-10 23:45:00+06\\")","(19,\\"2024-02-10 23:48:00+06\\")","(20,\\"2024-02-10 23:50:00+06\\")","(21,\\"2024-02-10 23:52:00+06\\")","(22,\\"2024-02-10 23:54:00+06\\")","(23,\\"2024-02-10 23:56:00+06\\")","(24,\\"2024-02-10 23:58:00+06\\")","(25,\\"2024-02-10 00:00:00+06\\")","(26,\\"2024-02-10 00:02:00+06\\")","(70,\\"2024-02-10 00:04:00+06\\")"}	from_buet	Ba-86-1841	t	abdulkarim6	nazmul	f	nasir81	t
2170	2024-02-10 12:40:00+06	4	morning	{"(27,\\"2024-02-10 12:40:00+06\\")","(28,\\"2024-02-10 12:42:00+06\\")","(29,\\"2024-02-10 12:44:00+06\\")","(30,\\"2024-02-10 12:46:00+06\\")","(31,\\"2024-02-10 12:50:00+06\\")","(32,\\"2024-02-10 12:52:00+06\\")","(33,\\"2024-02-10 12:54:00+06\\")","(34,\\"2024-02-10 12:58:00+06\\")","(35,\\"2024-02-10 13:00:00+06\\")","(70,\\"2024-02-10 13:10:00+06\\")"}	to_buet	Ba-85-4722	t	rafiqul	nazmul	f	zahir53	t
2171	2024-02-10 19:40:00+06	4	afternoon	{"(27,\\"2024-02-10 19:40:00+06\\")","(28,\\"2024-02-10 19:50:00+06\\")","(29,\\"2024-02-10 19:52:00+06\\")","(30,\\"2024-02-10 19:54:00+06\\")","(31,\\"2024-02-10 19:56:00+06\\")","(32,\\"2024-02-10 19:58:00+06\\")","(33,\\"2024-02-10 20:00:00+06\\")","(34,\\"2024-02-10 20:02:00+06\\")","(35,\\"2024-02-10 20:04:00+06\\")","(70,\\"2024-02-10 20:06:00+06\\")"}	from_buet	Ba-85-4722	t	rafiqul	nazmul	f	zahir53	t
2172	2024-02-10 23:30:00+06	4	evening	{"(27,\\"2024-02-10 23:30:00+06\\")","(28,\\"2024-02-10 23:40:00+06\\")","(29,\\"2024-02-10 23:42:00+06\\")","(30,\\"2024-02-10 23:44:00+06\\")","(31,\\"2024-02-10 23:46:00+06\\")","(32,\\"2024-02-10 23:48:00+06\\")","(33,\\"2024-02-10 23:50:00+06\\")","(34,\\"2024-02-10 23:52:00+06\\")","(35,\\"2024-02-10 23:54:00+06\\")","(70,\\"2024-02-10 23:56:00+06\\")"}	from_buet	Ba-85-4722	t	rafiqul	nazmul	f	zahir53	t
2173	2024-02-10 12:30:00+06	5	morning	{"(36,\\"2024-02-10 12:30:00+06\\")","(37,\\"2024-02-10 12:33:00+06\\")","(38,\\"2024-02-10 12:40:00+06\\")","(39,\\"2024-02-10 12:45:00+06\\")","(40,\\"2024-02-10 12:50:00+06\\")","(70,\\"2024-02-10 13:00:00+06\\")"}	to_buet	Ba-22-4326	t	fazlu77	nazmul	f	rashid56	t
2174	2024-02-10 19:40:00+06	5	afternoon	{"(36,\\"2024-02-10 19:40:00+06\\")","(37,\\"2024-02-10 19:50:00+06\\")","(38,\\"2024-02-10 19:55:00+06\\")","(39,\\"2024-02-10 20:00:00+06\\")","(40,\\"2024-02-10 20:07:00+06\\")","(70,\\"2024-02-10 20:10:00+06\\")"}	from_buet	Ba-22-4326	t	fazlu77	nazmul	f	rashid56	t
2176	2024-02-10 12:40:00+06	6	morning	{"(41,\\"2024-02-10 12:40:00+06\\")","(42,\\"2024-02-10 12:42:00+06\\")","(43,\\"2024-02-10 12:45:00+06\\")","(44,\\"2024-02-10 12:47:00+06\\")","(45,\\"2024-02-10 12:49:00+06\\")","(46,\\"2024-02-10 12:51:00+06\\")","(47,\\"2024-02-10 12:52:00+06\\")","(48,\\"2024-02-10 12:53:00+06\\")","(49,\\"2024-02-10 12:54:00+06\\")","(70,\\"2024-02-10 13:10:00+06\\")"}	to_buet	Ba-20-3066	t	arif43	nazmul	f	jamal7898	t
2177	2024-02-10 19:40:00+06	6	afternoon	{"(41,\\"2024-02-10 19:40:00+06\\")","(42,\\"2024-02-10 19:56:00+06\\")","(43,\\"2024-02-10 19:58:00+06\\")","(44,\\"2024-02-10 20:00:00+06\\")","(45,\\"2024-02-10 20:02:00+06\\")","(46,\\"2024-02-10 20:04:00+06\\")","(47,\\"2024-02-10 20:06:00+06\\")","(48,\\"2024-02-10 20:08:00+06\\")","(49,\\"2024-02-10 20:10:00+06\\")","(70,\\"2024-02-10 20:12:00+06\\")"}	from_buet	Ba-20-3066	t	arif43	nazmul	f	jamal7898	t
2178	2024-02-10 23:30:00+06	6	evening	{"(41,\\"2024-02-10 23:30:00+06\\")","(42,\\"2024-02-10 23:46:00+06\\")","(43,\\"2024-02-10 23:48:00+06\\")","(44,\\"2024-02-10 23:50:00+06\\")","(45,\\"2024-02-10 23:52:00+06\\")","(46,\\"2024-02-10 23:54:00+06\\")","(47,\\"2024-02-10 23:56:00+06\\")","(48,\\"2024-02-10 23:58:00+06\\")","(49,\\"2024-02-10 00:00:00+06\\")","(70,\\"2024-02-10 00:02:00+06\\")"}	from_buet	Ba-20-3066	t	arif43	nazmul	f	jamal7898	t
2179	2024-02-10 12:40:00+06	7	morning	{"(50,\\"2024-02-10 12:40:00+06\\")","(51,\\"2024-02-10 12:42:00+06\\")","(52,\\"2024-02-10 12:43:00+06\\")","(53,\\"2024-02-10 12:46:00+06\\")","(54,\\"2024-02-10 12:47:00+06\\")","(55,\\"2024-02-10 12:48:00+06\\")","(56,\\"2024-02-10 12:50:00+06\\")","(57,\\"2024-02-10 12:52:00+06\\")","(58,\\"2024-02-10 12:53:00+06\\")","(59,\\"2024-02-10 12:54:00+06\\")","(60,\\"2024-02-10 12:56:00+06\\")","(61,\\"2024-02-10 12:58:00+06\\")","(62,\\"2024-02-10 13:00:00+06\\")","(63,\\"2024-02-10 13:02:00+06\\")","(70,\\"2024-02-10 13:00:00+06\\")"}	to_buet	Ba-46-1334	t	nazrul6	nazmul	f	reyazul	t
2180	2024-02-10 19:40:00+06	7	afternoon	{"(50,\\"2024-02-10 19:40:00+06\\")","(51,\\"2024-02-10 19:48:00+06\\")","(52,\\"2024-02-10 19:50:00+06\\")","(53,\\"2024-02-10 19:52:00+06\\")","(54,\\"2024-02-10 19:54:00+06\\")","(55,\\"2024-02-10 19:56:00+06\\")","(56,\\"2024-02-10 19:58:00+06\\")","(57,\\"2024-02-10 20:00:00+06\\")","(58,\\"2024-02-10 20:02:00+06\\")","(59,\\"2024-02-10 20:04:00+06\\")","(60,\\"2024-02-10 20:06:00+06\\")","(61,\\"2024-02-10 20:08:00+06\\")","(62,\\"2024-02-10 20:10:00+06\\")","(63,\\"2024-02-10 20:12:00+06\\")","(70,\\"2024-02-10 20:14:00+06\\")"}	from_buet	Ba-46-1334	t	nazrul6	nazmul	f	reyazul	t
2181	2024-02-10 23:30:00+06	7	evening	{"(50,\\"2024-02-10 23:30:00+06\\")","(51,\\"2024-02-10 23:38:00+06\\")","(52,\\"2024-02-10 23:40:00+06\\")","(53,\\"2024-02-10 23:42:00+06\\")","(54,\\"2024-02-10 23:44:00+06\\")","(55,\\"2024-02-10 23:46:00+06\\")","(56,\\"2024-02-10 23:48:00+06\\")","(57,\\"2024-02-10 23:50:00+06\\")","(58,\\"2024-02-10 23:52:00+06\\")","(59,\\"2024-02-10 23:54:00+06\\")","(60,\\"2024-02-10 23:56:00+06\\")","(61,\\"2024-02-10 23:58:00+06\\")","(62,\\"2024-02-10 00:00:00+06\\")","(63,\\"2024-02-10 00:02:00+06\\")","(70,\\"2024-02-10 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	nazrul6	nazmul	f	reyazul	t
2182	2024-02-10 12:15:00+06	1	morning	{"(1,\\"2024-02-10 12:15:00+06\\")","(2,\\"2024-02-10 12:18:00+06\\")","(3,\\"2024-02-10 12:20:00+06\\")","(4,\\"2024-02-10 12:23:00+06\\")","(5,\\"2024-02-10 12:26:00+06\\")","(6,\\"2024-02-10 12:29:00+06\\")","(7,\\"2024-02-10 12:49:00+06\\")","(8,\\"2024-02-10 12:51:00+06\\")","(9,\\"2024-02-10 12:53:00+06\\")","(10,\\"2024-02-10 12:55:00+06\\")","(11,\\"2024-02-10 12:58:00+06\\")","(70,\\"2024-02-10 13:05:00+06\\")"}	to_buet	Ba-71-7930	t	nizam88	nazmul	f	sharif86r	t
2183	2024-02-10 19:40:00+06	1	afternoon	{"(1,\\"2024-02-10 19:40:00+06\\")","(2,\\"2024-02-10 19:47:00+06\\")","(3,\\"2024-02-10 19:50:00+06\\")","(4,\\"2024-02-10 19:52:00+06\\")","(5,\\"2024-02-10 19:54:00+06\\")","(6,\\"2024-02-10 20:06:00+06\\")","(7,\\"2024-02-10 20:09:00+06\\")","(8,\\"2024-02-10 20:12:00+06\\")","(9,\\"2024-02-10 20:15:00+06\\")","(10,\\"2024-02-10 20:18:00+06\\")","(11,\\"2024-02-10 20:21:00+06\\")","(70,\\"2024-02-10 20:24:00+06\\")"}	from_buet	Ba-71-7930	t	nizam88	nazmul	f	sharif86r	t
2184	2024-02-10 23:30:00+06	1	evening	{"(1,\\"2024-02-10 23:30:00+06\\")","(2,\\"2024-02-10 23:37:00+06\\")","(3,\\"2024-02-10 23:40:00+06\\")","(4,\\"2024-02-10 23:42:00+06\\")","(5,\\"2024-02-10 23:44:00+06\\")","(6,\\"2024-02-10 23:56:00+06\\")","(7,\\"2024-02-10 23:59:00+06\\")","(8,\\"2024-02-10 00:02:00+06\\")","(9,\\"2024-02-10 00:05:00+06\\")","(10,\\"2024-02-10 00:08:00+06\\")","(11,\\"2024-02-10 00:11:00+06\\")","(70,\\"2024-02-10 00:14:00+06\\")"}	from_buet	Ba-71-7930	t	nizam88	nazmul	f	sharif86r	t
2185	2024-02-10 12:10:00+06	8	morning	{"(64,\\"2024-02-10 12:10:00+06\\")","(65,\\"2024-02-10 12:13:00+06\\")","(66,\\"2024-02-10 12:18:00+06\\")","(67,\\"2024-02-10 12:20:00+06\\")","(68,\\"2024-02-10 12:22:00+06\\")","(69,\\"2024-02-10 12:25:00+06\\")","(70,\\"2024-02-10 12:40:00+06\\")"}	to_buet	Ba-63-1146	t	kamaluddin	nazmul	f	shamsul54	t
2186	2024-02-10 19:40:00+06	8	afternoon	{"(64,\\"2024-02-10 19:40:00+06\\")","(65,\\"2024-02-10 19:55:00+06\\")","(66,\\"2024-02-10 19:58:00+06\\")","(67,\\"2024-02-10 20:01:00+06\\")","(68,\\"2024-02-10 20:04:00+06\\")","(69,\\"2024-02-10 20:07:00+06\\")","(70,\\"2024-02-10 20:10:00+06\\")"}	from_buet	Ba-63-1146	t	kamaluddin	nazmul	f	shamsul54	t
2187	2024-02-10 23:30:00+06	8	evening	{"(64,\\"2024-02-10 23:30:00+06\\")","(65,\\"2024-02-10 23:45:00+06\\")","(66,\\"2024-02-10 23:48:00+06\\")","(67,\\"2024-02-10 23:51:00+06\\")","(68,\\"2024-02-10 23:54:00+06\\")","(69,\\"2024-02-10 23:57:00+06\\")","(70,\\"2024-02-10 00:00:00+06\\")"}	from_buet	Ba-63-1146	t	kamaluddin	nazmul	f	shamsul54	t
2188	2024-02-11 12:55:00+06	2	morning	{"(12,\\"2024-02-11 12:55:00+06\\")","(13,\\"2024-02-11 12:57:00+06\\")","(14,\\"2024-02-11 12:59:00+06\\")","(15,\\"2024-02-11 13:01:00+06\\")","(16,\\"2024-02-11 13:03:00+06\\")","(70,\\"2024-02-11 13:15:00+06\\")"}	to_buet	Ba-12-8888	t	rashed3	nazmul	f	siddiq2	t
2189	2024-02-11 19:40:00+06	2	afternoon	{"(12,\\"2024-02-11 19:40:00+06\\")","(13,\\"2024-02-11 19:52:00+06\\")","(14,\\"2024-02-11 19:54:00+06\\")","(15,\\"2024-02-11 19:57:00+06\\")","(16,\\"2024-02-11 20:00:00+06\\")","(70,\\"2024-02-11 20:03:00+06\\")"}	from_buet	Ba-12-8888	t	rashed3	nazmul	f	siddiq2	t
2190	2024-02-11 23:30:00+06	2	evening	{"(12,\\"2024-02-11 23:30:00+06\\")","(13,\\"2024-02-11 23:42:00+06\\")","(14,\\"2024-02-11 23:45:00+06\\")","(15,\\"2024-02-11 23:48:00+06\\")","(16,\\"2024-02-11 23:51:00+06\\")","(70,\\"2024-02-11 23:54:00+06\\")"}	from_buet	Ba-12-8888	t	rashed3	nazmul	f	siddiq2	t
2191	2024-02-11 12:40:00+06	3	morning	{"(17,\\"2024-02-11 12:40:00+06\\")","(18,\\"2024-02-11 12:42:00+06\\")","(19,\\"2024-02-11 12:44:00+06\\")","(20,\\"2024-02-11 12:46:00+06\\")","(21,\\"2024-02-11 12:48:00+06\\")","(22,\\"2024-02-11 12:50:00+06\\")","(23,\\"2024-02-11 12:52:00+06\\")","(24,\\"2024-02-11 12:54:00+06\\")","(25,\\"2024-02-11 12:57:00+06\\")","(26,\\"2024-02-11 13:00:00+06\\")","(70,\\"2024-02-11 13:15:00+06\\")"}	to_buet	Ba-77-7044	t	kamaluddin	nazmul	f	rashid56	t
2192	2024-02-11 19:40:00+06	3	afternoon	{"(17,\\"2024-02-11 19:40:00+06\\")","(18,\\"2024-02-11 19:55:00+06\\")","(19,\\"2024-02-11 19:58:00+06\\")","(20,\\"2024-02-11 20:00:00+06\\")","(21,\\"2024-02-11 20:02:00+06\\")","(22,\\"2024-02-11 20:04:00+06\\")","(23,\\"2024-02-11 20:06:00+06\\")","(24,\\"2024-02-11 20:08:00+06\\")","(25,\\"2024-02-11 20:10:00+06\\")","(26,\\"2024-02-11 20:12:00+06\\")","(70,\\"2024-02-11 20:14:00+06\\")"}	from_buet	Ba-77-7044	t	kamaluddin	nazmul	f	rashid56	t
2193	2024-02-11 23:30:00+06	3	evening	{"(17,\\"2024-02-11 23:30:00+06\\")","(18,\\"2024-02-11 23:45:00+06\\")","(19,\\"2024-02-11 23:48:00+06\\")","(20,\\"2024-02-11 23:50:00+06\\")","(21,\\"2024-02-11 23:52:00+06\\")","(22,\\"2024-02-11 23:54:00+06\\")","(23,\\"2024-02-11 23:56:00+06\\")","(24,\\"2024-02-11 23:58:00+06\\")","(25,\\"2024-02-11 00:00:00+06\\")","(26,\\"2024-02-11 00:02:00+06\\")","(70,\\"2024-02-11 00:04:00+06\\")"}	from_buet	Ba-77-7044	t	kamaluddin	nazmul	f	rashid56	t
2194	2024-02-11 12:40:00+06	4	morning	{"(27,\\"2024-02-11 12:40:00+06\\")","(28,\\"2024-02-11 12:42:00+06\\")","(29,\\"2024-02-11 12:44:00+06\\")","(30,\\"2024-02-11 12:46:00+06\\")","(31,\\"2024-02-11 12:50:00+06\\")","(32,\\"2024-02-11 12:52:00+06\\")","(33,\\"2024-02-11 12:54:00+06\\")","(34,\\"2024-02-11 12:58:00+06\\")","(35,\\"2024-02-11 13:00:00+06\\")","(70,\\"2024-02-11 13:10:00+06\\")"}	to_buet	Ba-34-7413	t	aminhaque	nazmul	f	azim990	t
2195	2024-02-11 19:40:00+06	4	afternoon	{"(27,\\"2024-02-11 19:40:00+06\\")","(28,\\"2024-02-11 19:50:00+06\\")","(29,\\"2024-02-11 19:52:00+06\\")","(30,\\"2024-02-11 19:54:00+06\\")","(31,\\"2024-02-11 19:56:00+06\\")","(32,\\"2024-02-11 19:58:00+06\\")","(33,\\"2024-02-11 20:00:00+06\\")","(34,\\"2024-02-11 20:02:00+06\\")","(35,\\"2024-02-11 20:04:00+06\\")","(70,\\"2024-02-11 20:06:00+06\\")"}	from_buet	Ba-34-7413	t	aminhaque	nazmul	f	azim990	t
2196	2024-02-11 23:30:00+06	4	evening	{"(27,\\"2024-02-11 23:30:00+06\\")","(28,\\"2024-02-11 23:40:00+06\\")","(29,\\"2024-02-11 23:42:00+06\\")","(30,\\"2024-02-11 23:44:00+06\\")","(31,\\"2024-02-11 23:46:00+06\\")","(32,\\"2024-02-11 23:48:00+06\\")","(33,\\"2024-02-11 23:50:00+06\\")","(34,\\"2024-02-11 23:52:00+06\\")","(35,\\"2024-02-11 23:54:00+06\\")","(70,\\"2024-02-11 23:56:00+06\\")"}	from_buet	Ba-34-7413	t	aminhaque	nazmul	f	azim990	t
2200	2024-02-11 12:40:00+06	6	morning	{"(41,\\"2024-02-11 12:40:00+06\\")","(42,\\"2024-02-11 12:42:00+06\\")","(43,\\"2024-02-11 12:45:00+06\\")","(44,\\"2024-02-11 12:47:00+06\\")","(45,\\"2024-02-11 12:49:00+06\\")","(46,\\"2024-02-11 12:51:00+06\\")","(47,\\"2024-02-11 12:52:00+06\\")","(48,\\"2024-02-11 12:53:00+06\\")","(49,\\"2024-02-11 12:54:00+06\\")","(70,\\"2024-02-11 13:10:00+06\\")"}	to_buet	Ba-46-1334	t	jahangir	nazmul	f	reyazul	t
2201	2024-02-11 19:40:00+06	6	afternoon	{"(41,\\"2024-02-11 19:40:00+06\\")","(42,\\"2024-02-11 19:56:00+06\\")","(43,\\"2024-02-11 19:58:00+06\\")","(44,\\"2024-02-11 20:00:00+06\\")","(45,\\"2024-02-11 20:02:00+06\\")","(46,\\"2024-02-11 20:04:00+06\\")","(47,\\"2024-02-11 20:06:00+06\\")","(48,\\"2024-02-11 20:08:00+06\\")","(49,\\"2024-02-11 20:10:00+06\\")","(70,\\"2024-02-11 20:12:00+06\\")"}	from_buet	Ba-46-1334	t	jahangir	nazmul	f	reyazul	t
2202	2024-02-11 23:30:00+06	6	evening	{"(41,\\"2024-02-11 23:30:00+06\\")","(42,\\"2024-02-11 23:46:00+06\\")","(43,\\"2024-02-11 23:48:00+06\\")","(44,\\"2024-02-11 23:50:00+06\\")","(45,\\"2024-02-11 23:52:00+06\\")","(46,\\"2024-02-11 23:54:00+06\\")","(47,\\"2024-02-11 23:56:00+06\\")","(48,\\"2024-02-11 23:58:00+06\\")","(49,\\"2024-02-11 00:00:00+06\\")","(70,\\"2024-02-11 00:02:00+06\\")"}	from_buet	Ba-46-1334	t	jahangir	nazmul	f	reyazul	t
2203	2024-02-11 12:40:00+06	7	morning	{"(50,\\"2024-02-11 12:40:00+06\\")","(51,\\"2024-02-11 12:42:00+06\\")","(52,\\"2024-02-11 12:43:00+06\\")","(53,\\"2024-02-11 12:46:00+06\\")","(54,\\"2024-02-11 12:47:00+06\\")","(55,\\"2024-02-11 12:48:00+06\\")","(56,\\"2024-02-11 12:50:00+06\\")","(57,\\"2024-02-11 12:52:00+06\\")","(58,\\"2024-02-11 12:53:00+06\\")","(59,\\"2024-02-11 12:54:00+06\\")","(60,\\"2024-02-11 12:56:00+06\\")","(61,\\"2024-02-11 12:58:00+06\\")","(62,\\"2024-02-11 13:00:00+06\\")","(63,\\"2024-02-11 13:02:00+06\\")","(70,\\"2024-02-11 13:00:00+06\\")"}	to_buet	Ba-20-3066	t	monu67	nazmul	f	mahabhu	t
2204	2024-02-11 19:40:00+06	7	afternoon	{"(50,\\"2024-02-11 19:40:00+06\\")","(51,\\"2024-02-11 19:48:00+06\\")","(52,\\"2024-02-11 19:50:00+06\\")","(53,\\"2024-02-11 19:52:00+06\\")","(54,\\"2024-02-11 19:54:00+06\\")","(55,\\"2024-02-11 19:56:00+06\\")","(56,\\"2024-02-11 19:58:00+06\\")","(57,\\"2024-02-11 20:00:00+06\\")","(58,\\"2024-02-11 20:02:00+06\\")","(59,\\"2024-02-11 20:04:00+06\\")","(60,\\"2024-02-11 20:06:00+06\\")","(61,\\"2024-02-11 20:08:00+06\\")","(62,\\"2024-02-11 20:10:00+06\\")","(63,\\"2024-02-11 20:12:00+06\\")","(70,\\"2024-02-11 20:14:00+06\\")"}	from_buet	Ba-20-3066	t	monu67	nazmul	f	mahabhu	t
2205	2024-02-11 23:30:00+06	7	evening	{"(50,\\"2024-02-11 23:30:00+06\\")","(51,\\"2024-02-11 23:38:00+06\\")","(52,\\"2024-02-11 23:40:00+06\\")","(53,\\"2024-02-11 23:42:00+06\\")","(54,\\"2024-02-11 23:44:00+06\\")","(55,\\"2024-02-11 23:46:00+06\\")","(56,\\"2024-02-11 23:48:00+06\\")","(57,\\"2024-02-11 23:50:00+06\\")","(58,\\"2024-02-11 23:52:00+06\\")","(59,\\"2024-02-11 23:54:00+06\\")","(60,\\"2024-02-11 23:56:00+06\\")","(61,\\"2024-02-11 23:58:00+06\\")","(62,\\"2024-02-11 00:00:00+06\\")","(63,\\"2024-02-11 00:02:00+06\\")","(70,\\"2024-02-11 00:04:00+06\\")"}	from_buet	Ba-20-3066	t	monu67	nazmul	f	mahabhu	t
2206	2024-02-11 12:15:00+06	1	morning	{"(1,\\"2024-02-11 12:15:00+06\\")","(2,\\"2024-02-11 12:18:00+06\\")","(3,\\"2024-02-11 12:20:00+06\\")","(4,\\"2024-02-11 12:23:00+06\\")","(5,\\"2024-02-11 12:26:00+06\\")","(6,\\"2024-02-11 12:29:00+06\\")","(7,\\"2024-02-11 12:49:00+06\\")","(8,\\"2024-02-11 12:51:00+06\\")","(9,\\"2024-02-11 12:53:00+06\\")","(10,\\"2024-02-11 12:55:00+06\\")","(11,\\"2024-02-11 12:58:00+06\\")","(70,\\"2024-02-11 13:05:00+06\\")"}	to_buet	Ba-17-3886	t	arif43	nazmul	f	farid99	t
2207	2024-02-11 19:40:00+06	1	afternoon	{"(1,\\"2024-02-11 19:40:00+06\\")","(2,\\"2024-02-11 19:47:00+06\\")","(3,\\"2024-02-11 19:50:00+06\\")","(4,\\"2024-02-11 19:52:00+06\\")","(5,\\"2024-02-11 19:54:00+06\\")","(6,\\"2024-02-11 20:06:00+06\\")","(7,\\"2024-02-11 20:09:00+06\\")","(8,\\"2024-02-11 20:12:00+06\\")","(9,\\"2024-02-11 20:15:00+06\\")","(10,\\"2024-02-11 20:18:00+06\\")","(11,\\"2024-02-11 20:21:00+06\\")","(70,\\"2024-02-11 20:24:00+06\\")"}	from_buet	Ba-17-3886	t	arif43	nazmul	f	farid99	t
2208	2024-02-11 23:30:00+06	1	evening	{"(1,\\"2024-02-11 23:30:00+06\\")","(2,\\"2024-02-11 23:37:00+06\\")","(3,\\"2024-02-11 23:40:00+06\\")","(4,\\"2024-02-11 23:42:00+06\\")","(5,\\"2024-02-11 23:44:00+06\\")","(6,\\"2024-02-11 23:56:00+06\\")","(7,\\"2024-02-11 23:59:00+06\\")","(8,\\"2024-02-11 00:02:00+06\\")","(9,\\"2024-02-11 00:05:00+06\\")","(10,\\"2024-02-11 00:08:00+06\\")","(11,\\"2024-02-11 00:11:00+06\\")","(70,\\"2024-02-11 00:14:00+06\\")"}	from_buet	Ba-17-3886	t	arif43	nazmul	f	farid99	t
2209	2024-02-11 12:10:00+06	8	morning	{"(64,\\"2024-02-11 12:10:00+06\\")","(65,\\"2024-02-11 12:13:00+06\\")","(66,\\"2024-02-11 12:18:00+06\\")","(67,\\"2024-02-11 12:20:00+06\\")","(68,\\"2024-02-11 12:22:00+06\\")","(69,\\"2024-02-11 12:25:00+06\\")","(70,\\"2024-02-11 12:40:00+06\\")"}	to_buet	Ba-83-8014	t	imranhashmi	nazmul	f	zahir53	t
2210	2024-02-11 19:40:00+06	8	afternoon	{"(64,\\"2024-02-11 19:40:00+06\\")","(65,\\"2024-02-11 19:55:00+06\\")","(66,\\"2024-02-11 19:58:00+06\\")","(67,\\"2024-02-11 20:01:00+06\\")","(68,\\"2024-02-11 20:04:00+06\\")","(69,\\"2024-02-11 20:07:00+06\\")","(70,\\"2024-02-11 20:10:00+06\\")"}	from_buet	Ba-83-8014	t	imranhashmi	nazmul	f	zahir53	t
2211	2024-02-11 23:30:00+06	8	evening	{"(64,\\"2024-02-11 23:30:00+06\\")","(65,\\"2024-02-11 23:45:00+06\\")","(66,\\"2024-02-11 23:48:00+06\\")","(67,\\"2024-02-11 23:51:00+06\\")","(68,\\"2024-02-11 23:54:00+06\\")","(69,\\"2024-02-11 23:57:00+06\\")","(70,\\"2024-02-11 00:00:00+06\\")"}	from_buet	Ba-83-8014	t	imranhashmi	nazmul	f	zahir53	t
2212	2024-02-12 12:55:00+06	2	morning	{"(12,\\"2024-02-12 12:55:00+06\\")","(13,\\"2024-02-12 12:57:00+06\\")","(14,\\"2024-02-12 12:59:00+06\\")","(15,\\"2024-02-12 13:01:00+06\\")","(16,\\"2024-02-12 13:03:00+06\\")","(70,\\"2024-02-12 13:15:00+06\\")"}	to_buet	Ba-12-8888	t	shafiqul	nazmul	f	ASADUZZAMAN	t
2213	2024-02-12 19:40:00+06	2	afternoon	{"(12,\\"2024-02-12 19:40:00+06\\")","(13,\\"2024-02-12 19:52:00+06\\")","(14,\\"2024-02-12 19:54:00+06\\")","(15,\\"2024-02-12 19:57:00+06\\")","(16,\\"2024-02-12 20:00:00+06\\")","(70,\\"2024-02-12 20:03:00+06\\")"}	from_buet	Ba-12-8888	t	shafiqul	nazmul	f	ASADUZZAMAN	t
2214	2024-02-12 23:30:00+06	2	evening	{"(12,\\"2024-02-12 23:30:00+06\\")","(13,\\"2024-02-12 23:42:00+06\\")","(14,\\"2024-02-12 23:45:00+06\\")","(15,\\"2024-02-12 23:48:00+06\\")","(16,\\"2024-02-12 23:51:00+06\\")","(70,\\"2024-02-12 23:54:00+06\\")"}	from_buet	Ba-12-8888	t	shafiqul	nazmul	f	ASADUZZAMAN	t
2215	2024-02-12 12:40:00+06	3	morning	{"(17,\\"2024-02-12 12:40:00+06\\")","(18,\\"2024-02-12 12:42:00+06\\")","(19,\\"2024-02-12 12:44:00+06\\")","(20,\\"2024-02-12 12:46:00+06\\")","(21,\\"2024-02-12 12:48:00+06\\")","(22,\\"2024-02-12 12:50:00+06\\")","(23,\\"2024-02-12 12:52:00+06\\")","(24,\\"2024-02-12 12:54:00+06\\")","(25,\\"2024-02-12 12:57:00+06\\")","(26,\\"2024-02-12 13:00:00+06\\")","(70,\\"2024-02-12 13:15:00+06\\")"}	to_buet	Ba-17-3886	t	fazlu77	nazmul	f	mahbub777	t
2216	2024-02-12 19:40:00+06	3	afternoon	{"(17,\\"2024-02-12 19:40:00+06\\")","(18,\\"2024-02-12 19:55:00+06\\")","(19,\\"2024-02-12 19:58:00+06\\")","(20,\\"2024-02-12 20:00:00+06\\")","(21,\\"2024-02-12 20:02:00+06\\")","(22,\\"2024-02-12 20:04:00+06\\")","(23,\\"2024-02-12 20:06:00+06\\")","(24,\\"2024-02-12 20:08:00+06\\")","(25,\\"2024-02-12 20:10:00+06\\")","(26,\\"2024-02-12 20:12:00+06\\")","(70,\\"2024-02-12 20:14:00+06\\")"}	from_buet	Ba-17-3886	t	fazlu77	nazmul	f	mahbub777	t
2217	2024-02-12 23:30:00+06	3	evening	{"(17,\\"2024-02-12 23:30:00+06\\")","(18,\\"2024-02-12 23:45:00+06\\")","(19,\\"2024-02-12 23:48:00+06\\")","(20,\\"2024-02-12 23:50:00+06\\")","(21,\\"2024-02-12 23:52:00+06\\")","(22,\\"2024-02-12 23:54:00+06\\")","(23,\\"2024-02-12 23:56:00+06\\")","(24,\\"2024-02-12 23:58:00+06\\")","(25,\\"2024-02-12 00:00:00+06\\")","(26,\\"2024-02-12 00:02:00+06\\")","(70,\\"2024-02-12 00:04:00+06\\")"}	from_buet	Ba-17-3886	t	fazlu77	nazmul	f	mahbub777	t
2218	2024-02-12 12:40:00+06	4	morning	{"(27,\\"2024-02-12 12:40:00+06\\")","(28,\\"2024-02-12 12:42:00+06\\")","(29,\\"2024-02-12 12:44:00+06\\")","(30,\\"2024-02-12 12:46:00+06\\")","(31,\\"2024-02-12 12:50:00+06\\")","(32,\\"2024-02-12 12:52:00+06\\")","(33,\\"2024-02-12 12:54:00+06\\")","(34,\\"2024-02-12 12:58:00+06\\")","(35,\\"2024-02-12 13:00:00+06\\")","(70,\\"2024-02-12 13:10:00+06\\")"}	to_buet	Ba-36-1921	t	kamaluddin	nazmul	f	farid99	t
2219	2024-02-12 19:40:00+06	4	afternoon	{"(27,\\"2024-02-12 19:40:00+06\\")","(28,\\"2024-02-12 19:50:00+06\\")","(29,\\"2024-02-12 19:52:00+06\\")","(30,\\"2024-02-12 19:54:00+06\\")","(31,\\"2024-02-12 19:56:00+06\\")","(32,\\"2024-02-12 19:58:00+06\\")","(33,\\"2024-02-12 20:00:00+06\\")","(34,\\"2024-02-12 20:02:00+06\\")","(35,\\"2024-02-12 20:04:00+06\\")","(70,\\"2024-02-12 20:06:00+06\\")"}	from_buet	Ba-36-1921	t	kamaluddin	nazmul	f	farid99	t
2220	2024-02-12 23:30:00+06	4	evening	{"(27,\\"2024-02-12 23:30:00+06\\")","(28,\\"2024-02-12 23:40:00+06\\")","(29,\\"2024-02-12 23:42:00+06\\")","(30,\\"2024-02-12 23:44:00+06\\")","(31,\\"2024-02-12 23:46:00+06\\")","(32,\\"2024-02-12 23:48:00+06\\")","(33,\\"2024-02-12 23:50:00+06\\")","(34,\\"2024-02-12 23:52:00+06\\")","(35,\\"2024-02-12 23:54:00+06\\")","(70,\\"2024-02-12 23:56:00+06\\")"}	from_buet	Ba-36-1921	t	kamaluddin	nazmul	f	farid99	t
2224	2024-02-12 12:40:00+06	6	morning	{"(41,\\"2024-02-12 12:40:00+06\\")","(42,\\"2024-02-12 12:42:00+06\\")","(43,\\"2024-02-12 12:45:00+06\\")","(44,\\"2024-02-12 12:47:00+06\\")","(45,\\"2024-02-12 12:49:00+06\\")","(46,\\"2024-02-12 12:51:00+06\\")","(47,\\"2024-02-12 12:52:00+06\\")","(48,\\"2024-02-12 12:53:00+06\\")","(49,\\"2024-02-12 12:54:00+06\\")","(70,\\"2024-02-12 13:10:00+06\\")"}	to_buet	Ba-97-6734	t	abdulkarim6	nazmul	f	khairul	t
2225	2024-02-12 19:40:00+06	6	afternoon	{"(41,\\"2024-02-12 19:40:00+06\\")","(42,\\"2024-02-12 19:56:00+06\\")","(43,\\"2024-02-12 19:58:00+06\\")","(44,\\"2024-02-12 20:00:00+06\\")","(45,\\"2024-02-12 20:02:00+06\\")","(46,\\"2024-02-12 20:04:00+06\\")","(47,\\"2024-02-12 20:06:00+06\\")","(48,\\"2024-02-12 20:08:00+06\\")","(49,\\"2024-02-12 20:10:00+06\\")","(70,\\"2024-02-12 20:12:00+06\\")"}	from_buet	Ba-97-6734	t	abdulkarim6	nazmul	f	khairul	t
2226	2024-02-12 23:30:00+06	6	evening	{"(41,\\"2024-02-12 23:30:00+06\\")","(42,\\"2024-02-12 23:46:00+06\\")","(43,\\"2024-02-12 23:48:00+06\\")","(44,\\"2024-02-12 23:50:00+06\\")","(45,\\"2024-02-12 23:52:00+06\\")","(46,\\"2024-02-12 23:54:00+06\\")","(47,\\"2024-02-12 23:56:00+06\\")","(48,\\"2024-02-12 23:58:00+06\\")","(49,\\"2024-02-12 00:00:00+06\\")","(70,\\"2024-02-12 00:02:00+06\\")"}	from_buet	Ba-97-6734	t	abdulkarim6	nazmul	f	khairul	t
2227	2024-02-12 12:40:00+06	7	morning	{"(50,\\"2024-02-12 12:40:00+06\\")","(51,\\"2024-02-12 12:42:00+06\\")","(52,\\"2024-02-12 12:43:00+06\\")","(53,\\"2024-02-12 12:46:00+06\\")","(54,\\"2024-02-12 12:47:00+06\\")","(55,\\"2024-02-12 12:48:00+06\\")","(56,\\"2024-02-12 12:50:00+06\\")","(57,\\"2024-02-12 12:52:00+06\\")","(58,\\"2024-02-12 12:53:00+06\\")","(59,\\"2024-02-12 12:54:00+06\\")","(60,\\"2024-02-12 12:56:00+06\\")","(61,\\"2024-02-12 12:58:00+06\\")","(62,\\"2024-02-12 13:00:00+06\\")","(63,\\"2024-02-12 13:02:00+06\\")","(70,\\"2024-02-12 13:00:00+06\\")"}	to_buet	Ba-86-1841	t	imranhashmi	nazmul	f	azim990	t
2228	2024-02-12 19:40:00+06	7	afternoon	{"(50,\\"2024-02-12 19:40:00+06\\")","(51,\\"2024-02-12 19:48:00+06\\")","(52,\\"2024-02-12 19:50:00+06\\")","(53,\\"2024-02-12 19:52:00+06\\")","(54,\\"2024-02-12 19:54:00+06\\")","(55,\\"2024-02-12 19:56:00+06\\")","(56,\\"2024-02-12 19:58:00+06\\")","(57,\\"2024-02-12 20:00:00+06\\")","(58,\\"2024-02-12 20:02:00+06\\")","(59,\\"2024-02-12 20:04:00+06\\")","(60,\\"2024-02-12 20:06:00+06\\")","(61,\\"2024-02-12 20:08:00+06\\")","(62,\\"2024-02-12 20:10:00+06\\")","(63,\\"2024-02-12 20:12:00+06\\")","(70,\\"2024-02-12 20:14:00+06\\")"}	from_buet	Ba-86-1841	t	imranhashmi	nazmul	f	azim990	t
2229	2024-02-12 23:30:00+06	7	evening	{"(50,\\"2024-02-12 23:30:00+06\\")","(51,\\"2024-02-12 23:38:00+06\\")","(52,\\"2024-02-12 23:40:00+06\\")","(53,\\"2024-02-12 23:42:00+06\\")","(54,\\"2024-02-12 23:44:00+06\\")","(55,\\"2024-02-12 23:46:00+06\\")","(56,\\"2024-02-12 23:48:00+06\\")","(57,\\"2024-02-12 23:50:00+06\\")","(58,\\"2024-02-12 23:52:00+06\\")","(59,\\"2024-02-12 23:54:00+06\\")","(60,\\"2024-02-12 23:56:00+06\\")","(61,\\"2024-02-12 23:58:00+06\\")","(62,\\"2024-02-12 00:00:00+06\\")","(63,\\"2024-02-12 00:02:00+06\\")","(70,\\"2024-02-12 00:04:00+06\\")"}	from_buet	Ba-86-1841	t	imranhashmi	nazmul	f	azim990	t
2230	2024-02-12 12:15:00+06	1	morning	{"(1,\\"2024-02-12 12:15:00+06\\")","(2,\\"2024-02-12 12:18:00+06\\")","(3,\\"2024-02-12 12:20:00+06\\")","(4,\\"2024-02-12 12:23:00+06\\")","(5,\\"2024-02-12 12:26:00+06\\")","(6,\\"2024-02-12 12:29:00+06\\")","(7,\\"2024-02-12 12:49:00+06\\")","(8,\\"2024-02-12 12:51:00+06\\")","(9,\\"2024-02-12 12:53:00+06\\")","(10,\\"2024-02-12 12:55:00+06\\")","(11,\\"2024-02-12 12:58:00+06\\")","(70,\\"2024-02-12 13:05:00+06\\")"}	to_buet	Ba-77-7044	t	rashed3	nazmul	f	sharif86r	t
2231	2024-02-12 19:40:00+06	1	afternoon	{"(1,\\"2024-02-12 19:40:00+06\\")","(2,\\"2024-02-12 19:47:00+06\\")","(3,\\"2024-02-12 19:50:00+06\\")","(4,\\"2024-02-12 19:52:00+06\\")","(5,\\"2024-02-12 19:54:00+06\\")","(6,\\"2024-02-12 20:06:00+06\\")","(7,\\"2024-02-12 20:09:00+06\\")","(8,\\"2024-02-12 20:12:00+06\\")","(9,\\"2024-02-12 20:15:00+06\\")","(10,\\"2024-02-12 20:18:00+06\\")","(11,\\"2024-02-12 20:21:00+06\\")","(70,\\"2024-02-12 20:24:00+06\\")"}	from_buet	Ba-77-7044	t	rashed3	nazmul	f	sharif86r	t
2232	2024-02-12 23:30:00+06	1	evening	{"(1,\\"2024-02-12 23:30:00+06\\")","(2,\\"2024-02-12 23:37:00+06\\")","(3,\\"2024-02-12 23:40:00+06\\")","(4,\\"2024-02-12 23:42:00+06\\")","(5,\\"2024-02-12 23:44:00+06\\")","(6,\\"2024-02-12 23:56:00+06\\")","(7,\\"2024-02-12 23:59:00+06\\")","(8,\\"2024-02-12 00:02:00+06\\")","(9,\\"2024-02-12 00:05:00+06\\")","(10,\\"2024-02-12 00:08:00+06\\")","(11,\\"2024-02-12 00:11:00+06\\")","(70,\\"2024-02-12 00:14:00+06\\")"}	from_buet	Ba-77-7044	t	rashed3	nazmul	f	sharif86r	t
2233	2024-02-12 12:10:00+06	8	morning	{"(64,\\"2024-02-12 12:10:00+06\\")","(65,\\"2024-02-12 12:13:00+06\\")","(66,\\"2024-02-12 12:18:00+06\\")","(67,\\"2024-02-12 12:20:00+06\\")","(68,\\"2024-02-12 12:22:00+06\\")","(69,\\"2024-02-12 12:25:00+06\\")","(70,\\"2024-02-12 12:40:00+06\\")"}	to_buet	Ba-93-6087	t	masud84	nazmul	f	abdulbari4	t
2234	2024-02-12 19:40:00+06	8	afternoon	{"(64,\\"2024-02-12 19:40:00+06\\")","(65,\\"2024-02-12 19:55:00+06\\")","(66,\\"2024-02-12 19:58:00+06\\")","(67,\\"2024-02-12 20:01:00+06\\")","(68,\\"2024-02-12 20:04:00+06\\")","(69,\\"2024-02-12 20:07:00+06\\")","(70,\\"2024-02-12 20:10:00+06\\")"}	from_buet	Ba-93-6087	t	masud84	nazmul	f	abdulbari4	t
2235	2024-02-12 23:30:00+06	8	evening	{"(64,\\"2024-02-12 23:30:00+06\\")","(65,\\"2024-02-12 23:45:00+06\\")","(66,\\"2024-02-12 23:48:00+06\\")","(67,\\"2024-02-12 23:51:00+06\\")","(68,\\"2024-02-12 23:54:00+06\\")","(69,\\"2024-02-12 23:57:00+06\\")","(70,\\"2024-02-12 00:00:00+06\\")"}	from_buet	Ba-93-6087	t	masud84	nazmul	f	abdulbari4	t
2236	2024-02-14 12:55:00+06	2	morning	{"(12,\\"2024-02-14 12:55:00+06\\")","(13,\\"2024-02-14 12:57:00+06\\")","(14,\\"2024-02-14 12:59:00+06\\")","(15,\\"2024-02-14 13:01:00+06\\")","(16,\\"2024-02-14 13:03:00+06\\")","(70,\\"2024-02-14 13:15:00+06\\")"}	to_buet	Ba-17-3886	t	rahmatullah	nazmul	f	rashid56	t
2237	2024-02-14 19:40:00+06	2	afternoon	{"(12,\\"2024-02-14 19:40:00+06\\")","(13,\\"2024-02-14 19:52:00+06\\")","(14,\\"2024-02-14 19:54:00+06\\")","(15,\\"2024-02-14 19:57:00+06\\")","(16,\\"2024-02-14 20:00:00+06\\")","(70,\\"2024-02-14 20:03:00+06\\")"}	from_buet	Ba-17-3886	t	rahmatullah	nazmul	f	rashid56	t
2238	2024-02-14 23:30:00+06	2	evening	{"(12,\\"2024-02-14 23:30:00+06\\")","(13,\\"2024-02-14 23:42:00+06\\")","(14,\\"2024-02-14 23:45:00+06\\")","(15,\\"2024-02-14 23:48:00+06\\")","(16,\\"2024-02-14 23:51:00+06\\")","(70,\\"2024-02-14 23:54:00+06\\")"}	from_buet	Ba-17-3886	t	rahmatullah	nazmul	f	rashid56	t
2239	2024-02-14 12:40:00+06	3	morning	{"(17,\\"2024-02-14 12:40:00+06\\")","(18,\\"2024-02-14 12:42:00+06\\")","(19,\\"2024-02-14 12:44:00+06\\")","(20,\\"2024-02-14 12:46:00+06\\")","(21,\\"2024-02-14 12:48:00+06\\")","(22,\\"2024-02-14 12:50:00+06\\")","(23,\\"2024-02-14 12:52:00+06\\")","(24,\\"2024-02-14 12:54:00+06\\")","(25,\\"2024-02-14 12:57:00+06\\")","(26,\\"2024-02-14 13:00:00+06\\")","(70,\\"2024-02-14 13:15:00+06\\")"}	to_buet	Ba-43-4286	t	aminhaque	nazmul	f	shamsul54	t
2240	2024-02-14 19:40:00+06	3	afternoon	{"(17,\\"2024-02-14 19:40:00+06\\")","(18,\\"2024-02-14 19:55:00+06\\")","(19,\\"2024-02-14 19:58:00+06\\")","(20,\\"2024-02-14 20:00:00+06\\")","(21,\\"2024-02-14 20:02:00+06\\")","(22,\\"2024-02-14 20:04:00+06\\")","(23,\\"2024-02-14 20:06:00+06\\")","(24,\\"2024-02-14 20:08:00+06\\")","(25,\\"2024-02-14 20:10:00+06\\")","(26,\\"2024-02-14 20:12:00+06\\")","(70,\\"2024-02-14 20:14:00+06\\")"}	from_buet	Ba-43-4286	t	aminhaque	nazmul	f	shamsul54	t
2241	2024-02-14 23:30:00+06	3	evening	{"(17,\\"2024-02-14 23:30:00+06\\")","(18,\\"2024-02-14 23:45:00+06\\")","(19,\\"2024-02-14 23:48:00+06\\")","(20,\\"2024-02-14 23:50:00+06\\")","(21,\\"2024-02-14 23:52:00+06\\")","(22,\\"2024-02-14 23:54:00+06\\")","(23,\\"2024-02-14 23:56:00+06\\")","(24,\\"2024-02-14 23:58:00+06\\")","(25,\\"2024-02-14 00:00:00+06\\")","(26,\\"2024-02-14 00:02:00+06\\")","(70,\\"2024-02-14 00:04:00+06\\")"}	from_buet	Ba-43-4286	t	aminhaque	nazmul	f	shamsul54	t
2242	2024-02-14 12:40:00+06	4	morning	{"(27,\\"2024-02-14 12:40:00+06\\")","(28,\\"2024-02-14 12:42:00+06\\")","(29,\\"2024-02-14 12:44:00+06\\")","(30,\\"2024-02-14 12:46:00+06\\")","(31,\\"2024-02-14 12:50:00+06\\")","(32,\\"2024-02-14 12:52:00+06\\")","(33,\\"2024-02-14 12:54:00+06\\")","(34,\\"2024-02-14 12:58:00+06\\")","(35,\\"2024-02-14 13:00:00+06\\")","(70,\\"2024-02-14 13:10:00+06\\")"}	to_buet	Ba-46-1334	t	jahangir	nazmul	f	nasir81	t
2243	2024-02-14 19:40:00+06	4	afternoon	{"(27,\\"2024-02-14 19:40:00+06\\")","(28,\\"2024-02-14 19:50:00+06\\")","(29,\\"2024-02-14 19:52:00+06\\")","(30,\\"2024-02-14 19:54:00+06\\")","(31,\\"2024-02-14 19:56:00+06\\")","(32,\\"2024-02-14 19:58:00+06\\")","(33,\\"2024-02-14 20:00:00+06\\")","(34,\\"2024-02-14 20:02:00+06\\")","(35,\\"2024-02-14 20:04:00+06\\")","(70,\\"2024-02-14 20:06:00+06\\")"}	from_buet	Ba-46-1334	t	jahangir	nazmul	f	nasir81	t
2244	2024-02-14 23:30:00+06	4	evening	{"(27,\\"2024-02-14 23:30:00+06\\")","(28,\\"2024-02-14 23:40:00+06\\")","(29,\\"2024-02-14 23:42:00+06\\")","(30,\\"2024-02-14 23:44:00+06\\")","(31,\\"2024-02-14 23:46:00+06\\")","(32,\\"2024-02-14 23:48:00+06\\")","(33,\\"2024-02-14 23:50:00+06\\")","(34,\\"2024-02-14 23:52:00+06\\")","(35,\\"2024-02-14 23:54:00+06\\")","(70,\\"2024-02-14 23:56:00+06\\")"}	from_buet	Ba-46-1334	t	jahangir	nazmul	f	nasir81	t
2245	2024-02-14 12:30:00+06	5	morning	{"(36,\\"2024-02-14 12:30:00+06\\")","(37,\\"2024-02-14 12:33:00+06\\")","(38,\\"2024-02-14 12:40:00+06\\")","(39,\\"2024-02-14 12:45:00+06\\")","(40,\\"2024-02-14 12:50:00+06\\")","(70,\\"2024-02-14 13:00:00+06\\")"}	to_buet	Ba-85-4722	t	imranhashmi	nazmul	f	jamal7898	t
2246	2024-02-14 19:40:00+06	5	afternoon	{"(36,\\"2024-02-14 19:40:00+06\\")","(37,\\"2024-02-14 19:50:00+06\\")","(38,\\"2024-02-14 19:55:00+06\\")","(39,\\"2024-02-14 20:00:00+06\\")","(40,\\"2024-02-14 20:07:00+06\\")","(70,\\"2024-02-14 20:10:00+06\\")"}	from_buet	Ba-85-4722	t	imranhashmi	nazmul	f	jamal7898	t
2247	2024-02-14 23:30:00+06	5	evening	{"(36,\\"2024-02-14 23:30:00+06\\")","(37,\\"2024-02-14 23:40:00+06\\")","(38,\\"2024-02-14 23:45:00+06\\")","(39,\\"2024-02-14 23:50:00+06\\")","(40,\\"2024-02-14 23:57:00+06\\")","(70,\\"2024-02-14 00:00:00+06\\")"}	from_buet	Ba-85-4722	t	imranhashmi	nazmul	f	jamal7898	t
2248	2024-02-14 12:40:00+06	6	morning	{"(41,\\"2024-02-14 12:40:00+06\\")","(42,\\"2024-02-14 12:42:00+06\\")","(43,\\"2024-02-14 12:45:00+06\\")","(44,\\"2024-02-14 12:47:00+06\\")","(45,\\"2024-02-14 12:49:00+06\\")","(46,\\"2024-02-14 12:51:00+06\\")","(47,\\"2024-02-14 12:52:00+06\\")","(48,\\"2024-02-14 12:53:00+06\\")","(49,\\"2024-02-14 12:54:00+06\\")","(70,\\"2024-02-14 13:10:00+06\\")"}	to_buet	Ba-35-1461	t	monu67	nazmul	f	zahir53	t
2249	2024-02-14 19:40:00+06	6	afternoon	{"(41,\\"2024-02-14 19:40:00+06\\")","(42,\\"2024-02-14 19:56:00+06\\")","(43,\\"2024-02-14 19:58:00+06\\")","(44,\\"2024-02-14 20:00:00+06\\")","(45,\\"2024-02-14 20:02:00+06\\")","(46,\\"2024-02-14 20:04:00+06\\")","(47,\\"2024-02-14 20:06:00+06\\")","(48,\\"2024-02-14 20:08:00+06\\")","(49,\\"2024-02-14 20:10:00+06\\")","(70,\\"2024-02-14 20:12:00+06\\")"}	from_buet	Ba-35-1461	t	monu67	nazmul	f	zahir53	t
2250	2024-02-14 23:30:00+06	6	evening	{"(41,\\"2024-02-14 23:30:00+06\\")","(42,\\"2024-02-14 23:46:00+06\\")","(43,\\"2024-02-14 23:48:00+06\\")","(44,\\"2024-02-14 23:50:00+06\\")","(45,\\"2024-02-14 23:52:00+06\\")","(46,\\"2024-02-14 23:54:00+06\\")","(47,\\"2024-02-14 23:56:00+06\\")","(48,\\"2024-02-14 23:58:00+06\\")","(49,\\"2024-02-14 00:00:00+06\\")","(70,\\"2024-02-14 00:02:00+06\\")"}	from_buet	Ba-35-1461	t	monu67	nazmul	f	zahir53	t
2251	2024-02-14 12:40:00+06	7	morning	{"(50,\\"2024-02-14 12:40:00+06\\")","(51,\\"2024-02-14 12:42:00+06\\")","(52,\\"2024-02-14 12:43:00+06\\")","(53,\\"2024-02-14 12:46:00+06\\")","(54,\\"2024-02-14 12:47:00+06\\")","(55,\\"2024-02-14 12:48:00+06\\")","(56,\\"2024-02-14 12:50:00+06\\")","(57,\\"2024-02-14 12:52:00+06\\")","(58,\\"2024-02-14 12:53:00+06\\")","(59,\\"2024-02-14 12:54:00+06\\")","(60,\\"2024-02-14 12:56:00+06\\")","(61,\\"2024-02-14 12:58:00+06\\")","(62,\\"2024-02-14 13:00:00+06\\")","(63,\\"2024-02-14 13:02:00+06\\")","(70,\\"2024-02-14 13:00:00+06\\")"}	to_buet	Ba-69-8288	t	sohel55	nazmul	f	sharif86r	t
2252	2024-02-14 19:40:00+06	7	afternoon	{"(50,\\"2024-02-14 19:40:00+06\\")","(51,\\"2024-02-14 19:48:00+06\\")","(52,\\"2024-02-14 19:50:00+06\\")","(53,\\"2024-02-14 19:52:00+06\\")","(54,\\"2024-02-14 19:54:00+06\\")","(55,\\"2024-02-14 19:56:00+06\\")","(56,\\"2024-02-14 19:58:00+06\\")","(57,\\"2024-02-14 20:00:00+06\\")","(58,\\"2024-02-14 20:02:00+06\\")","(59,\\"2024-02-14 20:04:00+06\\")","(60,\\"2024-02-14 20:06:00+06\\")","(61,\\"2024-02-14 20:08:00+06\\")","(62,\\"2024-02-14 20:10:00+06\\")","(63,\\"2024-02-14 20:12:00+06\\")","(70,\\"2024-02-14 20:14:00+06\\")"}	from_buet	Ba-69-8288	t	sohel55	nazmul	f	sharif86r	t
2253	2024-02-14 23:30:00+06	7	evening	{"(50,\\"2024-02-14 23:30:00+06\\")","(51,\\"2024-02-14 23:38:00+06\\")","(52,\\"2024-02-14 23:40:00+06\\")","(53,\\"2024-02-14 23:42:00+06\\")","(54,\\"2024-02-14 23:44:00+06\\")","(55,\\"2024-02-14 23:46:00+06\\")","(56,\\"2024-02-14 23:48:00+06\\")","(57,\\"2024-02-14 23:50:00+06\\")","(58,\\"2024-02-14 23:52:00+06\\")","(59,\\"2024-02-14 23:54:00+06\\")","(60,\\"2024-02-14 23:56:00+06\\")","(61,\\"2024-02-14 23:58:00+06\\")","(62,\\"2024-02-14 00:00:00+06\\")","(63,\\"2024-02-14 00:02:00+06\\")","(70,\\"2024-02-14 00:04:00+06\\")"}	from_buet	Ba-69-8288	t	sohel55	nazmul	f	sharif86r	t
2254	2024-02-14 12:15:00+06	1	morning	{"(1,\\"2024-02-14 12:15:00+06\\")","(2,\\"2024-02-14 12:18:00+06\\")","(3,\\"2024-02-14 12:20:00+06\\")","(4,\\"2024-02-14 12:23:00+06\\")","(5,\\"2024-02-14 12:26:00+06\\")","(6,\\"2024-02-14 12:29:00+06\\")","(7,\\"2024-02-14 12:49:00+06\\")","(8,\\"2024-02-14 12:51:00+06\\")","(9,\\"2024-02-14 12:53:00+06\\")","(10,\\"2024-02-14 12:55:00+06\\")","(11,\\"2024-02-14 12:58:00+06\\")","(70,\\"2024-02-14 13:05:00+06\\")"}	to_buet	Ba-71-7930	t	fazlu77	nazmul	f	abdulbari4	t
2255	2024-02-14 19:40:00+06	1	afternoon	{"(1,\\"2024-02-14 19:40:00+06\\")","(2,\\"2024-02-14 19:47:00+06\\")","(3,\\"2024-02-14 19:50:00+06\\")","(4,\\"2024-02-14 19:52:00+06\\")","(5,\\"2024-02-14 19:54:00+06\\")","(6,\\"2024-02-14 20:06:00+06\\")","(7,\\"2024-02-14 20:09:00+06\\")","(8,\\"2024-02-14 20:12:00+06\\")","(9,\\"2024-02-14 20:15:00+06\\")","(10,\\"2024-02-14 20:18:00+06\\")","(11,\\"2024-02-14 20:21:00+06\\")","(70,\\"2024-02-14 20:24:00+06\\")"}	from_buet	Ba-71-7930	t	fazlu77	nazmul	f	abdulbari4	t
2256	2024-02-14 23:30:00+06	1	evening	{"(1,\\"2024-02-14 23:30:00+06\\")","(2,\\"2024-02-14 23:37:00+06\\")","(3,\\"2024-02-14 23:40:00+06\\")","(4,\\"2024-02-14 23:42:00+06\\")","(5,\\"2024-02-14 23:44:00+06\\")","(6,\\"2024-02-14 23:56:00+06\\")","(7,\\"2024-02-14 23:59:00+06\\")","(8,\\"2024-02-14 00:02:00+06\\")","(9,\\"2024-02-14 00:05:00+06\\")","(10,\\"2024-02-14 00:08:00+06\\")","(11,\\"2024-02-14 00:11:00+06\\")","(70,\\"2024-02-14 00:14:00+06\\")"}	from_buet	Ba-71-7930	t	fazlu77	nazmul	f	abdulbari4	t
2257	2024-02-14 12:10:00+06	8	morning	{"(64,\\"2024-02-14 12:10:00+06\\")","(65,\\"2024-02-14 12:13:00+06\\")","(66,\\"2024-02-14 12:18:00+06\\")","(67,\\"2024-02-14 12:20:00+06\\")","(68,\\"2024-02-14 12:22:00+06\\")","(69,\\"2024-02-14 12:25:00+06\\")","(70,\\"2024-02-14 12:40:00+06\\")"}	to_buet	Ba-12-8888	t	nazrul6	nazmul	f	mahabhu	t
2258	2024-02-14 19:40:00+06	8	afternoon	{"(64,\\"2024-02-14 19:40:00+06\\")","(65,\\"2024-02-14 19:55:00+06\\")","(66,\\"2024-02-14 19:58:00+06\\")","(67,\\"2024-02-14 20:01:00+06\\")","(68,\\"2024-02-14 20:04:00+06\\")","(69,\\"2024-02-14 20:07:00+06\\")","(70,\\"2024-02-14 20:10:00+06\\")"}	from_buet	Ba-12-8888	t	nazrul6	nazmul	f	mahabhu	t
2259	2024-02-14 23:30:00+06	8	evening	{"(64,\\"2024-02-14 23:30:00+06\\")","(65,\\"2024-02-14 23:45:00+06\\")","(66,\\"2024-02-14 23:48:00+06\\")","(67,\\"2024-02-14 23:51:00+06\\")","(68,\\"2024-02-14 23:54:00+06\\")","(69,\\"2024-02-14 23:57:00+06\\")","(70,\\"2024-02-14 00:00:00+06\\")"}	from_buet	Ba-12-8888	t	nazrul6	nazmul	f	mahabhu	t
2260	2024-02-15 12:55:00+06	2	morning	{"(12,\\"2024-02-15 12:55:00+06\\")","(13,\\"2024-02-15 12:57:00+06\\")","(14,\\"2024-02-15 12:59:00+06\\")","(15,\\"2024-02-15 13:01:00+06\\")","(16,\\"2024-02-15 13:03:00+06\\")","(70,\\"2024-02-15 13:15:00+06\\")"}	to_buet	BA-01-2345	t	rafiqul	nazmul	f	sharif86r	t
2261	2024-02-15 19:40:00+06	2	afternoon	{"(12,\\"2024-02-15 19:40:00+06\\")","(13,\\"2024-02-15 19:52:00+06\\")","(14,\\"2024-02-15 19:54:00+06\\")","(15,\\"2024-02-15 19:57:00+06\\")","(16,\\"2024-02-15 20:00:00+06\\")","(70,\\"2024-02-15 20:03:00+06\\")"}	from_buet	BA-01-2345	t	rafiqul	nazmul	f	sharif86r	t
2262	2024-02-15 23:30:00+06	2	evening	{"(12,\\"2024-02-15 23:30:00+06\\")","(13,\\"2024-02-15 23:42:00+06\\")","(14,\\"2024-02-15 23:45:00+06\\")","(15,\\"2024-02-15 23:48:00+06\\")","(16,\\"2024-02-15 23:51:00+06\\")","(70,\\"2024-02-15 23:54:00+06\\")"}	from_buet	BA-01-2345	t	rafiqul	nazmul	f	sharif86r	t
2263	2024-02-15 12:40:00+06	3	morning	{"(17,\\"2024-02-15 12:40:00+06\\")","(18,\\"2024-02-15 12:42:00+06\\")","(19,\\"2024-02-15 12:44:00+06\\")","(20,\\"2024-02-15 12:46:00+06\\")","(21,\\"2024-02-15 12:48:00+06\\")","(22,\\"2024-02-15 12:50:00+06\\")","(23,\\"2024-02-15 12:52:00+06\\")","(24,\\"2024-02-15 12:54:00+06\\")","(25,\\"2024-02-15 12:57:00+06\\")","(26,\\"2024-02-15 13:00:00+06\\")","(70,\\"2024-02-15 13:15:00+06\\")"}	to_buet	Ba-35-1461	t	nazrul6	nazmul	f	abdulbari4	t
2264	2024-02-15 19:40:00+06	3	afternoon	{"(17,\\"2024-02-15 19:40:00+06\\")","(18,\\"2024-02-15 19:55:00+06\\")","(19,\\"2024-02-15 19:58:00+06\\")","(20,\\"2024-02-15 20:00:00+06\\")","(21,\\"2024-02-15 20:02:00+06\\")","(22,\\"2024-02-15 20:04:00+06\\")","(23,\\"2024-02-15 20:06:00+06\\")","(24,\\"2024-02-15 20:08:00+06\\")","(25,\\"2024-02-15 20:10:00+06\\")","(26,\\"2024-02-15 20:12:00+06\\")","(70,\\"2024-02-15 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	nazrul6	nazmul	f	abdulbari4	t
2265	2024-02-15 23:30:00+06	3	evening	{"(17,\\"2024-02-15 23:30:00+06\\")","(18,\\"2024-02-15 23:45:00+06\\")","(19,\\"2024-02-15 23:48:00+06\\")","(20,\\"2024-02-15 23:50:00+06\\")","(21,\\"2024-02-15 23:52:00+06\\")","(22,\\"2024-02-15 23:54:00+06\\")","(23,\\"2024-02-15 23:56:00+06\\")","(24,\\"2024-02-15 23:58:00+06\\")","(25,\\"2024-02-15 00:00:00+06\\")","(26,\\"2024-02-15 00:02:00+06\\")","(70,\\"2024-02-15 00:04:00+06\\")"}	from_buet	Ba-35-1461	t	nazrul6	nazmul	f	abdulbari4	t
2266	2024-02-15 12:40:00+06	4	morning	{"(27,\\"2024-02-15 12:40:00+06\\")","(28,\\"2024-02-15 12:42:00+06\\")","(29,\\"2024-02-15 12:44:00+06\\")","(30,\\"2024-02-15 12:46:00+06\\")","(31,\\"2024-02-15 12:50:00+06\\")","(32,\\"2024-02-15 12:52:00+06\\")","(33,\\"2024-02-15 12:54:00+06\\")","(34,\\"2024-02-15 12:58:00+06\\")","(35,\\"2024-02-15 13:00:00+06\\")","(70,\\"2024-02-15 13:10:00+06\\")"}	to_buet	Ba-17-2081	t	monu67	nazmul	f	mahbub777	t
2267	2024-02-15 19:40:00+06	4	afternoon	{"(27,\\"2024-02-15 19:40:00+06\\")","(28,\\"2024-02-15 19:50:00+06\\")","(29,\\"2024-02-15 19:52:00+06\\")","(30,\\"2024-02-15 19:54:00+06\\")","(31,\\"2024-02-15 19:56:00+06\\")","(32,\\"2024-02-15 19:58:00+06\\")","(33,\\"2024-02-15 20:00:00+06\\")","(34,\\"2024-02-15 20:02:00+06\\")","(35,\\"2024-02-15 20:04:00+06\\")","(70,\\"2024-02-15 20:06:00+06\\")"}	from_buet	Ba-17-2081	t	monu67	nazmul	f	mahbub777	t
2268	2024-02-15 23:30:00+06	4	evening	{"(27,\\"2024-02-15 23:30:00+06\\")","(28,\\"2024-02-15 23:40:00+06\\")","(29,\\"2024-02-15 23:42:00+06\\")","(30,\\"2024-02-15 23:44:00+06\\")","(31,\\"2024-02-15 23:46:00+06\\")","(32,\\"2024-02-15 23:48:00+06\\")","(33,\\"2024-02-15 23:50:00+06\\")","(34,\\"2024-02-15 23:52:00+06\\")","(35,\\"2024-02-15 23:54:00+06\\")","(70,\\"2024-02-15 23:56:00+06\\")"}	from_buet	Ba-17-2081	t	monu67	nazmul	f	mahbub777	t
2269	2024-02-15 12:30:00+06	5	morning	{"(36,\\"2024-02-15 12:30:00+06\\")","(37,\\"2024-02-15 12:33:00+06\\")","(38,\\"2024-02-15 12:40:00+06\\")","(39,\\"2024-02-15 12:45:00+06\\")","(40,\\"2024-02-15 12:50:00+06\\")","(70,\\"2024-02-15 13:00:00+06\\")"}	to_buet	Ba-17-3886	t	abdulkarim6	nazmul	f	mahmud64	t
2270	2024-02-15 19:40:00+06	5	afternoon	{"(36,\\"2024-02-15 19:40:00+06\\")","(37,\\"2024-02-15 19:50:00+06\\")","(38,\\"2024-02-15 19:55:00+06\\")","(39,\\"2024-02-15 20:00:00+06\\")","(40,\\"2024-02-15 20:07:00+06\\")","(70,\\"2024-02-15 20:10:00+06\\")"}	from_buet	Ba-17-3886	t	abdulkarim6	nazmul	f	mahmud64	t
2271	2024-02-15 23:30:00+06	5	evening	{"(36,\\"2024-02-15 23:30:00+06\\")","(37,\\"2024-02-15 23:40:00+06\\")","(38,\\"2024-02-15 23:45:00+06\\")","(39,\\"2024-02-15 23:50:00+06\\")","(40,\\"2024-02-15 23:57:00+06\\")","(70,\\"2024-02-15 00:00:00+06\\")"}	from_buet	Ba-17-3886	t	abdulkarim6	nazmul	f	mahmud64	t
2272	2024-02-15 12:40:00+06	6	morning	{"(41,\\"2024-02-15 12:40:00+06\\")","(42,\\"2024-02-15 12:42:00+06\\")","(43,\\"2024-02-15 12:45:00+06\\")","(44,\\"2024-02-15 12:47:00+06\\")","(45,\\"2024-02-15 12:49:00+06\\")","(46,\\"2024-02-15 12:51:00+06\\")","(47,\\"2024-02-15 12:52:00+06\\")","(48,\\"2024-02-15 12:53:00+06\\")","(49,\\"2024-02-15 12:54:00+06\\")","(70,\\"2024-02-15 13:10:00+06\\")"}	to_buet	Ba-93-6087	t	imranhashmi	nazmul	f	rashid56	t
2273	2024-02-15 19:40:00+06	6	afternoon	{"(41,\\"2024-02-15 19:40:00+06\\")","(42,\\"2024-02-15 19:56:00+06\\")","(43,\\"2024-02-15 19:58:00+06\\")","(44,\\"2024-02-15 20:00:00+06\\")","(45,\\"2024-02-15 20:02:00+06\\")","(46,\\"2024-02-15 20:04:00+06\\")","(47,\\"2024-02-15 20:06:00+06\\")","(48,\\"2024-02-15 20:08:00+06\\")","(49,\\"2024-02-15 20:10:00+06\\")","(70,\\"2024-02-15 20:12:00+06\\")"}	from_buet	Ba-93-6087	t	imranhashmi	nazmul	f	rashid56	t
2274	2024-02-15 23:30:00+06	6	evening	{"(41,\\"2024-02-15 23:30:00+06\\")","(42,\\"2024-02-15 23:46:00+06\\")","(43,\\"2024-02-15 23:48:00+06\\")","(44,\\"2024-02-15 23:50:00+06\\")","(45,\\"2024-02-15 23:52:00+06\\")","(46,\\"2024-02-15 23:54:00+06\\")","(47,\\"2024-02-15 23:56:00+06\\")","(48,\\"2024-02-15 23:58:00+06\\")","(49,\\"2024-02-15 00:00:00+06\\")","(70,\\"2024-02-15 00:02:00+06\\")"}	from_buet	Ba-93-6087	t	imranhashmi	nazmul	f	rashid56	t
2275	2024-02-15 12:40:00+06	7	morning	{"(50,\\"2024-02-15 12:40:00+06\\")","(51,\\"2024-02-15 12:42:00+06\\")","(52,\\"2024-02-15 12:43:00+06\\")","(53,\\"2024-02-15 12:46:00+06\\")","(54,\\"2024-02-15 12:47:00+06\\")","(55,\\"2024-02-15 12:48:00+06\\")","(56,\\"2024-02-15 12:50:00+06\\")","(57,\\"2024-02-15 12:52:00+06\\")","(58,\\"2024-02-15 12:53:00+06\\")","(59,\\"2024-02-15 12:54:00+06\\")","(60,\\"2024-02-15 12:56:00+06\\")","(61,\\"2024-02-15 12:58:00+06\\")","(62,\\"2024-02-15 13:00:00+06\\")","(63,\\"2024-02-15 13:02:00+06\\")","(70,\\"2024-02-15 13:00:00+06\\")"}	to_buet	Ba-46-1334	t	masud84	nazmul	f	siddiq2	t
2276	2024-02-15 19:40:00+06	7	afternoon	{"(50,\\"2024-02-15 19:40:00+06\\")","(51,\\"2024-02-15 19:48:00+06\\")","(52,\\"2024-02-15 19:50:00+06\\")","(53,\\"2024-02-15 19:52:00+06\\")","(54,\\"2024-02-15 19:54:00+06\\")","(55,\\"2024-02-15 19:56:00+06\\")","(56,\\"2024-02-15 19:58:00+06\\")","(57,\\"2024-02-15 20:00:00+06\\")","(58,\\"2024-02-15 20:02:00+06\\")","(59,\\"2024-02-15 20:04:00+06\\")","(60,\\"2024-02-15 20:06:00+06\\")","(61,\\"2024-02-15 20:08:00+06\\")","(62,\\"2024-02-15 20:10:00+06\\")","(63,\\"2024-02-15 20:12:00+06\\")","(70,\\"2024-02-15 20:14:00+06\\")"}	from_buet	Ba-46-1334	t	masud84	nazmul	f	siddiq2	t
2277	2024-02-15 23:30:00+06	7	evening	{"(50,\\"2024-02-15 23:30:00+06\\")","(51,\\"2024-02-15 23:38:00+06\\")","(52,\\"2024-02-15 23:40:00+06\\")","(53,\\"2024-02-15 23:42:00+06\\")","(54,\\"2024-02-15 23:44:00+06\\")","(55,\\"2024-02-15 23:46:00+06\\")","(56,\\"2024-02-15 23:48:00+06\\")","(57,\\"2024-02-15 23:50:00+06\\")","(58,\\"2024-02-15 23:52:00+06\\")","(59,\\"2024-02-15 23:54:00+06\\")","(60,\\"2024-02-15 23:56:00+06\\")","(61,\\"2024-02-15 23:58:00+06\\")","(62,\\"2024-02-15 00:00:00+06\\")","(63,\\"2024-02-15 00:02:00+06\\")","(70,\\"2024-02-15 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	masud84	nazmul	f	siddiq2	t
2278	2024-02-15 12:15:00+06	1	morning	{"(1,\\"2024-02-15 12:15:00+06\\")","(2,\\"2024-02-15 12:18:00+06\\")","(3,\\"2024-02-15 12:20:00+06\\")","(4,\\"2024-02-15 12:23:00+06\\")","(5,\\"2024-02-15 12:26:00+06\\")","(6,\\"2024-02-15 12:29:00+06\\")","(7,\\"2024-02-15 12:49:00+06\\")","(8,\\"2024-02-15 12:51:00+06\\")","(9,\\"2024-02-15 12:53:00+06\\")","(10,\\"2024-02-15 12:55:00+06\\")","(11,\\"2024-02-15 12:58:00+06\\")","(70,\\"2024-02-15 13:05:00+06\\")"}	to_buet	Ba-20-3066	t	arif43	nazmul	f	ASADUZZAMAN	t
2279	2024-02-15 19:40:00+06	1	afternoon	{"(1,\\"2024-02-15 19:40:00+06\\")","(2,\\"2024-02-15 19:47:00+06\\")","(3,\\"2024-02-15 19:50:00+06\\")","(4,\\"2024-02-15 19:52:00+06\\")","(5,\\"2024-02-15 19:54:00+06\\")","(6,\\"2024-02-15 20:06:00+06\\")","(7,\\"2024-02-15 20:09:00+06\\")","(8,\\"2024-02-15 20:12:00+06\\")","(9,\\"2024-02-15 20:15:00+06\\")","(10,\\"2024-02-15 20:18:00+06\\")","(11,\\"2024-02-15 20:21:00+06\\")","(70,\\"2024-02-15 20:24:00+06\\")"}	from_buet	Ba-20-3066	t	arif43	nazmul	f	ASADUZZAMAN	t
2280	2024-02-15 23:30:00+06	1	evening	{"(1,\\"2024-02-15 23:30:00+06\\")","(2,\\"2024-02-15 23:37:00+06\\")","(3,\\"2024-02-15 23:40:00+06\\")","(4,\\"2024-02-15 23:42:00+06\\")","(5,\\"2024-02-15 23:44:00+06\\")","(6,\\"2024-02-15 23:56:00+06\\")","(7,\\"2024-02-15 23:59:00+06\\")","(8,\\"2024-02-15 00:02:00+06\\")","(9,\\"2024-02-15 00:05:00+06\\")","(10,\\"2024-02-15 00:08:00+06\\")","(11,\\"2024-02-15 00:11:00+06\\")","(70,\\"2024-02-15 00:14:00+06\\")"}	from_buet	Ba-20-3066	t	arif43	nazmul	f	ASADUZZAMAN	t
2281	2024-02-15 12:10:00+06	8	morning	{"(64,\\"2024-02-15 12:10:00+06\\")","(65,\\"2024-02-15 12:13:00+06\\")","(66,\\"2024-02-15 12:18:00+06\\")","(67,\\"2024-02-15 12:20:00+06\\")","(68,\\"2024-02-15 12:22:00+06\\")","(69,\\"2024-02-15 12:25:00+06\\")","(70,\\"2024-02-15 12:40:00+06\\")"}	to_buet	Ba-69-8288	t	ibrahim	nazmul	f	nasir81	t
2282	2024-02-15 19:40:00+06	8	afternoon	{"(64,\\"2024-02-15 19:40:00+06\\")","(65,\\"2024-02-15 19:55:00+06\\")","(66,\\"2024-02-15 19:58:00+06\\")","(67,\\"2024-02-15 20:01:00+06\\")","(68,\\"2024-02-15 20:04:00+06\\")","(69,\\"2024-02-15 20:07:00+06\\")","(70,\\"2024-02-15 20:10:00+06\\")"}	from_buet	Ba-69-8288	t	ibrahim	nazmul	f	nasir81	t
2283	2024-02-15 23:30:00+06	8	evening	{"(64,\\"2024-02-15 23:30:00+06\\")","(65,\\"2024-02-15 23:45:00+06\\")","(66,\\"2024-02-15 23:48:00+06\\")","(67,\\"2024-02-15 23:51:00+06\\")","(68,\\"2024-02-15 23:54:00+06\\")","(69,\\"2024-02-15 23:57:00+06\\")","(70,\\"2024-02-15 00:00:00+06\\")"}	from_buet	Ba-69-8288	t	ibrahim	nazmul	f	nasir81	t
2284	2024-02-16 12:55:00+06	2	morning	{"(12,\\"2024-02-16 12:55:00+06\\")","(13,\\"2024-02-16 12:57:00+06\\")","(14,\\"2024-02-16 12:59:00+06\\")","(15,\\"2024-02-16 13:01:00+06\\")","(16,\\"2024-02-16 13:03:00+06\\")","(70,\\"2024-02-16 13:15:00+06\\")"}	to_buet	Ba-83-8014	t	kamaluddin	nazmul	f	alamgir	t
2285	2024-02-16 19:40:00+06	2	afternoon	{"(12,\\"2024-02-16 19:40:00+06\\")","(13,\\"2024-02-16 19:52:00+06\\")","(14,\\"2024-02-16 19:54:00+06\\")","(15,\\"2024-02-16 19:57:00+06\\")","(16,\\"2024-02-16 20:00:00+06\\")","(70,\\"2024-02-16 20:03:00+06\\")"}	from_buet	Ba-83-8014	t	kamaluddin	nazmul	f	alamgir	t
2286	2024-02-16 23:30:00+06	2	evening	{"(12,\\"2024-02-16 23:30:00+06\\")","(13,\\"2024-02-16 23:42:00+06\\")","(14,\\"2024-02-16 23:45:00+06\\")","(15,\\"2024-02-16 23:48:00+06\\")","(16,\\"2024-02-16 23:51:00+06\\")","(70,\\"2024-02-16 23:54:00+06\\")"}	from_buet	Ba-83-8014	t	kamaluddin	nazmul	f	alamgir	t
2287	2024-02-16 12:40:00+06	3	morning	{"(17,\\"2024-02-16 12:40:00+06\\")","(18,\\"2024-02-16 12:42:00+06\\")","(19,\\"2024-02-16 12:44:00+06\\")","(20,\\"2024-02-16 12:46:00+06\\")","(21,\\"2024-02-16 12:48:00+06\\")","(22,\\"2024-02-16 12:50:00+06\\")","(23,\\"2024-02-16 12:52:00+06\\")","(24,\\"2024-02-16 12:54:00+06\\")","(25,\\"2024-02-16 12:57:00+06\\")","(26,\\"2024-02-16 13:00:00+06\\")","(70,\\"2024-02-16 13:15:00+06\\")"}	to_buet	Ba-35-1461	t	altaf78	nazmul	f	khairul	t
2288	2024-02-16 19:40:00+06	3	afternoon	{"(17,\\"2024-02-16 19:40:00+06\\")","(18,\\"2024-02-16 19:55:00+06\\")","(19,\\"2024-02-16 19:58:00+06\\")","(20,\\"2024-02-16 20:00:00+06\\")","(21,\\"2024-02-16 20:02:00+06\\")","(22,\\"2024-02-16 20:04:00+06\\")","(23,\\"2024-02-16 20:06:00+06\\")","(24,\\"2024-02-16 20:08:00+06\\")","(25,\\"2024-02-16 20:10:00+06\\")","(26,\\"2024-02-16 20:12:00+06\\")","(70,\\"2024-02-16 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	altaf78	nazmul	f	khairul	t
2289	2024-02-16 23:30:00+06	3	evening	{"(17,\\"2024-02-16 23:30:00+06\\")","(18,\\"2024-02-16 23:45:00+06\\")","(19,\\"2024-02-16 23:48:00+06\\")","(20,\\"2024-02-16 23:50:00+06\\")","(21,\\"2024-02-16 23:52:00+06\\")","(22,\\"2024-02-16 23:54:00+06\\")","(23,\\"2024-02-16 23:56:00+06\\")","(24,\\"2024-02-16 23:58:00+06\\")","(25,\\"2024-02-16 00:00:00+06\\")","(26,\\"2024-02-16 00:02:00+06\\")","(70,\\"2024-02-16 00:04:00+06\\")"}	from_buet	Ba-35-1461	t	altaf78	nazmul	f	khairul	t
2290	2024-02-16 12:40:00+06	4	morning	{"(27,\\"2024-02-16 12:40:00+06\\")","(28,\\"2024-02-16 12:42:00+06\\")","(29,\\"2024-02-16 12:44:00+06\\")","(30,\\"2024-02-16 12:46:00+06\\")","(31,\\"2024-02-16 12:50:00+06\\")","(32,\\"2024-02-16 12:52:00+06\\")","(33,\\"2024-02-16 12:54:00+06\\")","(34,\\"2024-02-16 12:58:00+06\\")","(35,\\"2024-02-16 13:00:00+06\\")","(70,\\"2024-02-16 13:10:00+06\\")"}	to_buet	Ba-20-3066	t	nazrul6	nazmul	f	farid99	t
2291	2024-02-16 19:40:00+06	4	afternoon	{"(27,\\"2024-02-16 19:40:00+06\\")","(28,\\"2024-02-16 19:50:00+06\\")","(29,\\"2024-02-16 19:52:00+06\\")","(30,\\"2024-02-16 19:54:00+06\\")","(31,\\"2024-02-16 19:56:00+06\\")","(32,\\"2024-02-16 19:58:00+06\\")","(33,\\"2024-02-16 20:00:00+06\\")","(34,\\"2024-02-16 20:02:00+06\\")","(35,\\"2024-02-16 20:04:00+06\\")","(70,\\"2024-02-16 20:06:00+06\\")"}	from_buet	Ba-20-3066	t	nazrul6	nazmul	f	farid99	t
2292	2024-02-16 23:30:00+06	4	evening	{"(27,\\"2024-02-16 23:30:00+06\\")","(28,\\"2024-02-16 23:40:00+06\\")","(29,\\"2024-02-16 23:42:00+06\\")","(30,\\"2024-02-16 23:44:00+06\\")","(31,\\"2024-02-16 23:46:00+06\\")","(32,\\"2024-02-16 23:48:00+06\\")","(33,\\"2024-02-16 23:50:00+06\\")","(34,\\"2024-02-16 23:52:00+06\\")","(35,\\"2024-02-16 23:54:00+06\\")","(70,\\"2024-02-16 23:56:00+06\\")"}	from_buet	Ba-20-3066	t	nazrul6	nazmul	f	farid99	t
2293	2024-02-16 12:30:00+06	5	morning	{"(36,\\"2024-02-16 12:30:00+06\\")","(37,\\"2024-02-16 12:33:00+06\\")","(38,\\"2024-02-16 12:40:00+06\\")","(39,\\"2024-02-16 12:45:00+06\\")","(40,\\"2024-02-16 12:50:00+06\\")","(70,\\"2024-02-16 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	abdulkarim6	nazmul	f	abdulbari4	t
2294	2024-02-16 19:40:00+06	5	afternoon	{"(36,\\"2024-02-16 19:40:00+06\\")","(37,\\"2024-02-16 19:50:00+06\\")","(38,\\"2024-02-16 19:55:00+06\\")","(39,\\"2024-02-16 20:00:00+06\\")","(40,\\"2024-02-16 20:07:00+06\\")","(70,\\"2024-02-16 20:10:00+06\\")"}	from_buet	Ba-24-8518	t	abdulkarim6	nazmul	f	abdulbari4	t
2295	2024-02-16 23:30:00+06	5	evening	{"(36,\\"2024-02-16 23:30:00+06\\")","(37,\\"2024-02-16 23:40:00+06\\")","(38,\\"2024-02-16 23:45:00+06\\")","(39,\\"2024-02-16 23:50:00+06\\")","(40,\\"2024-02-16 23:57:00+06\\")","(70,\\"2024-02-16 00:00:00+06\\")"}	from_buet	Ba-24-8518	t	abdulkarim6	nazmul	f	abdulbari4	t
2296	2024-02-16 12:40:00+06	6	morning	{"(41,\\"2024-02-16 12:40:00+06\\")","(42,\\"2024-02-16 12:42:00+06\\")","(43,\\"2024-02-16 12:45:00+06\\")","(44,\\"2024-02-16 12:47:00+06\\")","(45,\\"2024-02-16 12:49:00+06\\")","(46,\\"2024-02-16 12:51:00+06\\")","(47,\\"2024-02-16 12:52:00+06\\")","(48,\\"2024-02-16 12:53:00+06\\")","(49,\\"2024-02-16 12:54:00+06\\")","(70,\\"2024-02-16 13:10:00+06\\")"}	to_buet	BA-01-2345	t	shafiqul	nazmul	f	ASADUZZAMAN	t
2297	2024-02-16 19:40:00+06	6	afternoon	{"(41,\\"2024-02-16 19:40:00+06\\")","(42,\\"2024-02-16 19:56:00+06\\")","(43,\\"2024-02-16 19:58:00+06\\")","(44,\\"2024-02-16 20:00:00+06\\")","(45,\\"2024-02-16 20:02:00+06\\")","(46,\\"2024-02-16 20:04:00+06\\")","(47,\\"2024-02-16 20:06:00+06\\")","(48,\\"2024-02-16 20:08:00+06\\")","(49,\\"2024-02-16 20:10:00+06\\")","(70,\\"2024-02-16 20:12:00+06\\")"}	from_buet	BA-01-2345	t	shafiqul	nazmul	f	ASADUZZAMAN	t
2298	2024-02-16 23:30:00+06	6	evening	{"(41,\\"2024-02-16 23:30:00+06\\")","(42,\\"2024-02-16 23:46:00+06\\")","(43,\\"2024-02-16 23:48:00+06\\")","(44,\\"2024-02-16 23:50:00+06\\")","(45,\\"2024-02-16 23:52:00+06\\")","(46,\\"2024-02-16 23:54:00+06\\")","(47,\\"2024-02-16 23:56:00+06\\")","(48,\\"2024-02-16 23:58:00+06\\")","(49,\\"2024-02-16 00:00:00+06\\")","(70,\\"2024-02-16 00:02:00+06\\")"}	from_buet	BA-01-2345	t	shafiqul	nazmul	f	ASADUZZAMAN	t
2299	2024-02-16 12:40:00+06	7	morning	{"(50,\\"2024-02-16 12:40:00+06\\")","(51,\\"2024-02-16 12:42:00+06\\")","(52,\\"2024-02-16 12:43:00+06\\")","(53,\\"2024-02-16 12:46:00+06\\")","(54,\\"2024-02-16 12:47:00+06\\")","(55,\\"2024-02-16 12:48:00+06\\")","(56,\\"2024-02-16 12:50:00+06\\")","(57,\\"2024-02-16 12:52:00+06\\")","(58,\\"2024-02-16 12:53:00+06\\")","(59,\\"2024-02-16 12:54:00+06\\")","(60,\\"2024-02-16 12:56:00+06\\")","(61,\\"2024-02-16 12:58:00+06\\")","(62,\\"2024-02-16 13:00:00+06\\")","(63,\\"2024-02-16 13:02:00+06\\")","(70,\\"2024-02-16 13:00:00+06\\")"}	to_buet	Ba-12-8888	t	nizam88	nazmul	f	reyazul	t
2300	2024-02-16 19:40:00+06	7	afternoon	{"(50,\\"2024-02-16 19:40:00+06\\")","(51,\\"2024-02-16 19:48:00+06\\")","(52,\\"2024-02-16 19:50:00+06\\")","(53,\\"2024-02-16 19:52:00+06\\")","(54,\\"2024-02-16 19:54:00+06\\")","(55,\\"2024-02-16 19:56:00+06\\")","(56,\\"2024-02-16 19:58:00+06\\")","(57,\\"2024-02-16 20:00:00+06\\")","(58,\\"2024-02-16 20:02:00+06\\")","(59,\\"2024-02-16 20:04:00+06\\")","(60,\\"2024-02-16 20:06:00+06\\")","(61,\\"2024-02-16 20:08:00+06\\")","(62,\\"2024-02-16 20:10:00+06\\")","(63,\\"2024-02-16 20:12:00+06\\")","(70,\\"2024-02-16 20:14:00+06\\")"}	from_buet	Ba-12-8888	t	nizam88	nazmul	f	reyazul	t
2317	2024-02-17 12:30:00+06	5	morning	{"(36,\\"2024-02-17 12:30:00+06\\")","(37,\\"2024-02-17 12:33:00+06\\")","(38,\\"2024-02-17 12:40:00+06\\")","(39,\\"2024-02-17 12:45:00+06\\")","(40,\\"2024-02-17 12:50:00+06\\")","(70,\\"2024-02-17 13:00:00+06\\")"}	to_buet	Ba-93-6087	t	nazrul6	nazmul	f	alamgir	t
2301	2024-02-16 23:30:00+06	7	evening	{"(50,\\"2024-02-16 23:30:00+06\\")","(51,\\"2024-02-16 23:38:00+06\\")","(52,\\"2024-02-16 23:40:00+06\\")","(53,\\"2024-02-16 23:42:00+06\\")","(54,\\"2024-02-16 23:44:00+06\\")","(55,\\"2024-02-16 23:46:00+06\\")","(56,\\"2024-02-16 23:48:00+06\\")","(57,\\"2024-02-16 23:50:00+06\\")","(58,\\"2024-02-16 23:52:00+06\\")","(59,\\"2024-02-16 23:54:00+06\\")","(60,\\"2024-02-16 23:56:00+06\\")","(61,\\"2024-02-16 23:58:00+06\\")","(62,\\"2024-02-16 00:00:00+06\\")","(63,\\"2024-02-16 00:02:00+06\\")","(70,\\"2024-02-16 00:04:00+06\\")"}	from_buet	Ba-12-8888	t	nizam88	nazmul	f	reyazul	t
2302	2024-02-16 12:15:00+06	1	morning	{"(1,\\"2024-02-16 12:15:00+06\\")","(2,\\"2024-02-16 12:18:00+06\\")","(3,\\"2024-02-16 12:20:00+06\\")","(4,\\"2024-02-16 12:23:00+06\\")","(5,\\"2024-02-16 12:26:00+06\\")","(6,\\"2024-02-16 12:29:00+06\\")","(7,\\"2024-02-16 12:49:00+06\\")","(8,\\"2024-02-16 12:51:00+06\\")","(9,\\"2024-02-16 12:53:00+06\\")","(10,\\"2024-02-16 12:55:00+06\\")","(11,\\"2024-02-16 12:58:00+06\\")","(70,\\"2024-02-16 13:05:00+06\\")"}	to_buet	Ba-46-1334	t	arif43	nazmul	f	rashid56	t
2303	2024-02-16 19:40:00+06	1	afternoon	{"(1,\\"2024-02-16 19:40:00+06\\")","(2,\\"2024-02-16 19:47:00+06\\")","(3,\\"2024-02-16 19:50:00+06\\")","(4,\\"2024-02-16 19:52:00+06\\")","(5,\\"2024-02-16 19:54:00+06\\")","(6,\\"2024-02-16 20:06:00+06\\")","(7,\\"2024-02-16 20:09:00+06\\")","(8,\\"2024-02-16 20:12:00+06\\")","(9,\\"2024-02-16 20:15:00+06\\")","(10,\\"2024-02-16 20:18:00+06\\")","(11,\\"2024-02-16 20:21:00+06\\")","(70,\\"2024-02-16 20:24:00+06\\")"}	from_buet	Ba-46-1334	t	arif43	nazmul	f	rashid56	t
2304	2024-02-16 23:30:00+06	1	evening	{"(1,\\"2024-02-16 23:30:00+06\\")","(2,\\"2024-02-16 23:37:00+06\\")","(3,\\"2024-02-16 23:40:00+06\\")","(4,\\"2024-02-16 23:42:00+06\\")","(5,\\"2024-02-16 23:44:00+06\\")","(6,\\"2024-02-16 23:56:00+06\\")","(7,\\"2024-02-16 23:59:00+06\\")","(8,\\"2024-02-16 00:02:00+06\\")","(9,\\"2024-02-16 00:05:00+06\\")","(10,\\"2024-02-16 00:08:00+06\\")","(11,\\"2024-02-16 00:11:00+06\\")","(70,\\"2024-02-16 00:14:00+06\\")"}	from_buet	Ba-46-1334	t	arif43	nazmul	f	rashid56	t
2305	2024-02-16 12:10:00+06	8	morning	{"(64,\\"2024-02-16 12:10:00+06\\")","(65,\\"2024-02-16 12:13:00+06\\")","(66,\\"2024-02-16 12:18:00+06\\")","(67,\\"2024-02-16 12:20:00+06\\")","(68,\\"2024-02-16 12:22:00+06\\")","(69,\\"2024-02-16 12:25:00+06\\")","(70,\\"2024-02-16 12:40:00+06\\")"}	to_buet	Ba-19-0569	t	masud84	nazmul	f	nasir81	t
2306	2024-02-16 19:40:00+06	8	afternoon	{"(64,\\"2024-02-16 19:40:00+06\\")","(65,\\"2024-02-16 19:55:00+06\\")","(66,\\"2024-02-16 19:58:00+06\\")","(67,\\"2024-02-16 20:01:00+06\\")","(68,\\"2024-02-16 20:04:00+06\\")","(69,\\"2024-02-16 20:07:00+06\\")","(70,\\"2024-02-16 20:10:00+06\\")"}	from_buet	Ba-19-0569	t	masud84	nazmul	f	nasir81	t
2307	2024-02-16 23:30:00+06	8	evening	{"(64,\\"2024-02-16 23:30:00+06\\")","(65,\\"2024-02-16 23:45:00+06\\")","(66,\\"2024-02-16 23:48:00+06\\")","(67,\\"2024-02-16 23:51:00+06\\")","(68,\\"2024-02-16 23:54:00+06\\")","(69,\\"2024-02-16 23:57:00+06\\")","(70,\\"2024-02-16 00:00:00+06\\")"}	from_buet	Ba-19-0569	t	masud84	nazmul	f	nasir81	t
2308	2024-02-17 12:55:00+06	2	morning	{"(12,\\"2024-02-17 12:55:00+06\\")","(13,\\"2024-02-17 12:57:00+06\\")","(14,\\"2024-02-17 12:59:00+06\\")","(15,\\"2024-02-17 13:01:00+06\\")","(16,\\"2024-02-17 13:03:00+06\\")","(70,\\"2024-02-17 13:15:00+06\\")"}	to_buet	Ba-22-4326	t	nizam88	nazmul	f	mahmud64	t
2309	2024-02-17 19:40:00+06	2	afternoon	{"(12,\\"2024-02-17 19:40:00+06\\")","(13,\\"2024-02-17 19:52:00+06\\")","(14,\\"2024-02-17 19:54:00+06\\")","(15,\\"2024-02-17 19:57:00+06\\")","(16,\\"2024-02-17 20:00:00+06\\")","(70,\\"2024-02-17 20:03:00+06\\")"}	from_buet	Ba-22-4326	t	nizam88	nazmul	f	mahmud64	t
2310	2024-02-17 23:30:00+06	2	evening	{"(12,\\"2024-02-17 23:30:00+06\\")","(13,\\"2024-02-17 23:42:00+06\\")","(14,\\"2024-02-17 23:45:00+06\\")","(15,\\"2024-02-17 23:48:00+06\\")","(16,\\"2024-02-17 23:51:00+06\\")","(70,\\"2024-02-17 23:54:00+06\\")"}	from_buet	Ba-22-4326	t	nizam88	nazmul	f	mahmud64	t
2314	2024-02-17 12:40:00+06	4	morning	{"(27,\\"2024-02-17 12:40:00+06\\")","(28,\\"2024-02-17 12:42:00+06\\")","(29,\\"2024-02-17 12:44:00+06\\")","(30,\\"2024-02-17 12:46:00+06\\")","(31,\\"2024-02-17 12:50:00+06\\")","(32,\\"2024-02-17 12:52:00+06\\")","(33,\\"2024-02-17 12:54:00+06\\")","(34,\\"2024-02-17 12:58:00+06\\")","(35,\\"2024-02-17 13:00:00+06\\")","(70,\\"2024-02-17 13:10:00+06\\")"}	to_buet	Ba-85-4722	t	rashed3	nazmul	f	khairul	t
2315	2024-02-17 19:40:00+06	4	afternoon	{"(27,\\"2024-02-17 19:40:00+06\\")","(28,\\"2024-02-17 19:50:00+06\\")","(29,\\"2024-02-17 19:52:00+06\\")","(30,\\"2024-02-17 19:54:00+06\\")","(31,\\"2024-02-17 19:56:00+06\\")","(32,\\"2024-02-17 19:58:00+06\\")","(33,\\"2024-02-17 20:00:00+06\\")","(34,\\"2024-02-17 20:02:00+06\\")","(35,\\"2024-02-17 20:04:00+06\\")","(70,\\"2024-02-17 20:06:00+06\\")"}	from_buet	Ba-85-4722	t	rashed3	nazmul	f	khairul	t
2316	2024-02-17 23:30:00+06	4	evening	{"(27,\\"2024-02-17 23:30:00+06\\")","(28,\\"2024-02-17 23:40:00+06\\")","(29,\\"2024-02-17 23:42:00+06\\")","(30,\\"2024-02-17 23:44:00+06\\")","(31,\\"2024-02-17 23:46:00+06\\")","(32,\\"2024-02-17 23:48:00+06\\")","(33,\\"2024-02-17 23:50:00+06\\")","(34,\\"2024-02-17 23:52:00+06\\")","(35,\\"2024-02-17 23:54:00+06\\")","(70,\\"2024-02-17 23:56:00+06\\")"}	from_buet	Ba-85-4722	t	rashed3	nazmul	f	khairul	t
2318	2024-02-17 19:40:00+06	5	afternoon	{"(36,\\"2024-02-17 19:40:00+06\\")","(37,\\"2024-02-17 19:50:00+06\\")","(38,\\"2024-02-17 19:55:00+06\\")","(39,\\"2024-02-17 20:00:00+06\\")","(40,\\"2024-02-17 20:07:00+06\\")","(70,\\"2024-02-17 20:10:00+06\\")"}	from_buet	Ba-93-6087	t	nazrul6	nazmul	f	alamgir	t
2319	2024-02-17 23:30:00+06	5	evening	{"(36,\\"2024-02-17 23:30:00+06\\")","(37,\\"2024-02-17 23:40:00+06\\")","(38,\\"2024-02-17 23:45:00+06\\")","(39,\\"2024-02-17 23:50:00+06\\")","(40,\\"2024-02-17 23:57:00+06\\")","(70,\\"2024-02-17 00:00:00+06\\")"}	from_buet	Ba-93-6087	t	nazrul6	nazmul	f	alamgir	t
2320	2024-02-17 12:40:00+06	6	morning	{"(41,\\"2024-02-17 12:40:00+06\\")","(42,\\"2024-02-17 12:42:00+06\\")","(43,\\"2024-02-17 12:45:00+06\\")","(44,\\"2024-02-17 12:47:00+06\\")","(45,\\"2024-02-17 12:49:00+06\\")","(46,\\"2024-02-17 12:51:00+06\\")","(47,\\"2024-02-17 12:52:00+06\\")","(48,\\"2024-02-17 12:53:00+06\\")","(49,\\"2024-02-17 12:54:00+06\\")","(70,\\"2024-02-17 13:10:00+06\\")"}	to_buet	Ba-43-4286	t	altaf78	nazmul	f	farid99	t
2321	2024-02-17 19:40:00+06	6	afternoon	{"(41,\\"2024-02-17 19:40:00+06\\")","(42,\\"2024-02-17 19:56:00+06\\")","(43,\\"2024-02-17 19:58:00+06\\")","(44,\\"2024-02-17 20:00:00+06\\")","(45,\\"2024-02-17 20:02:00+06\\")","(46,\\"2024-02-17 20:04:00+06\\")","(47,\\"2024-02-17 20:06:00+06\\")","(48,\\"2024-02-17 20:08:00+06\\")","(49,\\"2024-02-17 20:10:00+06\\")","(70,\\"2024-02-17 20:12:00+06\\")"}	from_buet	Ba-43-4286	t	altaf78	nazmul	f	farid99	t
2322	2024-02-17 23:30:00+06	6	evening	{"(41,\\"2024-02-17 23:30:00+06\\")","(42,\\"2024-02-17 23:46:00+06\\")","(43,\\"2024-02-17 23:48:00+06\\")","(44,\\"2024-02-17 23:50:00+06\\")","(45,\\"2024-02-17 23:52:00+06\\")","(46,\\"2024-02-17 23:54:00+06\\")","(47,\\"2024-02-17 23:56:00+06\\")","(48,\\"2024-02-17 23:58:00+06\\")","(49,\\"2024-02-17 00:00:00+06\\")","(70,\\"2024-02-17 00:02:00+06\\")"}	from_buet	Ba-43-4286	t	altaf78	nazmul	f	farid99	t
2323	2024-02-17 12:40:00+06	7	morning	{"(50,\\"2024-02-17 12:40:00+06\\")","(51,\\"2024-02-17 12:42:00+06\\")","(52,\\"2024-02-17 12:43:00+06\\")","(53,\\"2024-02-17 12:46:00+06\\")","(54,\\"2024-02-17 12:47:00+06\\")","(55,\\"2024-02-17 12:48:00+06\\")","(56,\\"2024-02-17 12:50:00+06\\")","(57,\\"2024-02-17 12:52:00+06\\")","(58,\\"2024-02-17 12:53:00+06\\")","(59,\\"2024-02-17 12:54:00+06\\")","(60,\\"2024-02-17 12:56:00+06\\")","(61,\\"2024-02-17 12:58:00+06\\")","(62,\\"2024-02-17 13:00:00+06\\")","(63,\\"2024-02-17 13:02:00+06\\")","(70,\\"2024-02-17 13:00:00+06\\")"}	to_buet	Ba-48-5757	t	shafiqul	nazmul	f	zahir53	t
2324	2024-02-17 19:40:00+06	7	afternoon	{"(50,\\"2024-02-17 19:40:00+06\\")","(51,\\"2024-02-17 19:48:00+06\\")","(52,\\"2024-02-17 19:50:00+06\\")","(53,\\"2024-02-17 19:52:00+06\\")","(54,\\"2024-02-17 19:54:00+06\\")","(55,\\"2024-02-17 19:56:00+06\\")","(56,\\"2024-02-17 19:58:00+06\\")","(57,\\"2024-02-17 20:00:00+06\\")","(58,\\"2024-02-17 20:02:00+06\\")","(59,\\"2024-02-17 20:04:00+06\\")","(60,\\"2024-02-17 20:06:00+06\\")","(61,\\"2024-02-17 20:08:00+06\\")","(62,\\"2024-02-17 20:10:00+06\\")","(63,\\"2024-02-17 20:12:00+06\\")","(70,\\"2024-02-17 20:14:00+06\\")"}	from_buet	Ba-48-5757	t	shafiqul	nazmul	f	zahir53	t
2325	2024-02-17 23:30:00+06	7	evening	{"(50,\\"2024-02-17 23:30:00+06\\")","(51,\\"2024-02-17 23:38:00+06\\")","(52,\\"2024-02-17 23:40:00+06\\")","(53,\\"2024-02-17 23:42:00+06\\")","(54,\\"2024-02-17 23:44:00+06\\")","(55,\\"2024-02-17 23:46:00+06\\")","(56,\\"2024-02-17 23:48:00+06\\")","(57,\\"2024-02-17 23:50:00+06\\")","(58,\\"2024-02-17 23:52:00+06\\")","(59,\\"2024-02-17 23:54:00+06\\")","(60,\\"2024-02-17 23:56:00+06\\")","(61,\\"2024-02-17 23:58:00+06\\")","(62,\\"2024-02-17 00:00:00+06\\")","(63,\\"2024-02-17 00:02:00+06\\")","(70,\\"2024-02-17 00:04:00+06\\")"}	from_buet	Ba-48-5757	t	shafiqul	nazmul	f	zahir53	t
2326	2024-02-17 12:15:00+06	1	morning	{"(1,\\"2024-02-17 12:15:00+06\\")","(2,\\"2024-02-17 12:18:00+06\\")","(3,\\"2024-02-17 12:20:00+06\\")","(4,\\"2024-02-17 12:23:00+06\\")","(5,\\"2024-02-17 12:26:00+06\\")","(6,\\"2024-02-17 12:29:00+06\\")","(7,\\"2024-02-17 12:49:00+06\\")","(8,\\"2024-02-17 12:51:00+06\\")","(9,\\"2024-02-17 12:53:00+06\\")","(10,\\"2024-02-17 12:55:00+06\\")","(11,\\"2024-02-17 12:58:00+06\\")","(70,\\"2024-02-17 13:05:00+06\\")"}	to_buet	Ba-71-7930	t	rafiqul	nazmul	f	jamal7898	t
2327	2024-02-17 19:40:00+06	1	afternoon	{"(1,\\"2024-02-17 19:40:00+06\\")","(2,\\"2024-02-17 19:47:00+06\\")","(3,\\"2024-02-17 19:50:00+06\\")","(4,\\"2024-02-17 19:52:00+06\\")","(5,\\"2024-02-17 19:54:00+06\\")","(6,\\"2024-02-17 20:06:00+06\\")","(7,\\"2024-02-17 20:09:00+06\\")","(8,\\"2024-02-17 20:12:00+06\\")","(9,\\"2024-02-17 20:15:00+06\\")","(10,\\"2024-02-17 20:18:00+06\\")","(11,\\"2024-02-17 20:21:00+06\\")","(70,\\"2024-02-17 20:24:00+06\\")"}	from_buet	Ba-71-7930	t	rafiqul	nazmul	f	jamal7898	t
2328	2024-02-17 23:30:00+06	1	evening	{"(1,\\"2024-02-17 23:30:00+06\\")","(2,\\"2024-02-17 23:37:00+06\\")","(3,\\"2024-02-17 23:40:00+06\\")","(4,\\"2024-02-17 23:42:00+06\\")","(5,\\"2024-02-17 23:44:00+06\\")","(6,\\"2024-02-17 23:56:00+06\\")","(7,\\"2024-02-17 23:59:00+06\\")","(8,\\"2024-02-17 00:02:00+06\\")","(9,\\"2024-02-17 00:05:00+06\\")","(10,\\"2024-02-17 00:08:00+06\\")","(11,\\"2024-02-17 00:11:00+06\\")","(70,\\"2024-02-17 00:14:00+06\\")"}	from_buet	Ba-71-7930	t	rafiqul	nazmul	f	jamal7898	t
2329	2024-02-17 12:10:00+06	8	morning	{"(64,\\"2024-02-17 12:10:00+06\\")","(65,\\"2024-02-17 12:13:00+06\\")","(66,\\"2024-02-17 12:18:00+06\\")","(67,\\"2024-02-17 12:20:00+06\\")","(68,\\"2024-02-17 12:22:00+06\\")","(69,\\"2024-02-17 12:25:00+06\\")","(70,\\"2024-02-17 12:40:00+06\\")"}	to_buet	Ba-77-7044	t	ibrahim	nazmul	f	siddiq2	t
2330	2024-02-17 19:40:00+06	8	afternoon	{"(64,\\"2024-02-17 19:40:00+06\\")","(65,\\"2024-02-17 19:55:00+06\\")","(66,\\"2024-02-17 19:58:00+06\\")","(67,\\"2024-02-17 20:01:00+06\\")","(68,\\"2024-02-17 20:04:00+06\\")","(69,\\"2024-02-17 20:07:00+06\\")","(70,\\"2024-02-17 20:10:00+06\\")"}	from_buet	Ba-77-7044	t	ibrahim	nazmul	f	siddiq2	t
2331	2024-02-17 23:30:00+06	8	evening	{"(64,\\"2024-02-17 23:30:00+06\\")","(65,\\"2024-02-17 23:45:00+06\\")","(66,\\"2024-02-17 23:48:00+06\\")","(67,\\"2024-02-17 23:51:00+06\\")","(68,\\"2024-02-17 23:54:00+06\\")","(69,\\"2024-02-17 23:57:00+06\\")","(70,\\"2024-02-17 00:00:00+06\\")"}	from_buet	Ba-77-7044	t	ibrahim	nazmul	f	siddiq2	t
\.


--
-- Data for Name: assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.assignment (id, route, bus, driver, helper, valid) FROM stdin;
\.


--
-- Data for Name: broadcast_notification; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.broadcast_notification (id, text, "timestamp") FROM stdin;
\.


--
-- Data for Name: buet_staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buet_staff (id, name, department, designation, residence, password, phone, valid) FROM stdin;
mashiat	Mashiat Mustaq	CSE	Lecturer	Kallyanpur	$2a$12$VA1Ffp.8bQxwb31j4uGyrOLPmMFV9aLbfDyePOb4JyddnU3jI6tDm	01234567890	t
rayhan	Rayhan Rashed	CSE	Lecturer	Mohammadpur	$2a$12$Jx5HtdLxU7AbC1A4woVma.Lxb/so.AXAkLcyFxre8XquWlGkuw4EC	01234567890	t
younus	Junayed Younus Khan	CSE	Professor	Teachers' Quarter	$2a$12$weSHv8XdkPsuJxDDZ6CpEOvSIe43.oxsxArDPVamLwtg2ua1IC5GS	01234567890	t
fahim	Sheikh Azizul Hakim	CSE	Lecturer	Demra	$2a$12$5WeTox.wKCUYbABO8YVXu.SMYS75PeUylE/s/gm90Gf5ZduNd.jp.	01911302328	t
jawad	Jawad Ul Alam	EEE	Lecturer	Nakhalpara	$2a$12$7amLXXhSxnw2NRv.AcMrKOEyLHepx8PSw7SpSeART.I.WEjfyy6rG	01633197399	t
mrinmoy	Mrinmoy Kundu	EEE	Lecturer	Khilgaon	$2a$12$3FdSJGqgzpTBwuRPSctBWuMp/XIqMB/yUc.4yjy7qvWZ83b/HFYEC	01637927525	t
pranto	Md. Toufikuzzaman	CSE	Lecturer	Guwahati	$2a$12$moUka1mC52nCG7y1chEJH.aRJjSTT28AjJlTu3AE7QvrLeAe07NJC	01845896525	t
sayem	Sayem Hasan	CSE	Lecturer	Basabo	$2a$12$WBEXHaoMcQ.c/ivn8fFIXeGkwB9oDYzu.HFfWcwj89mi.90PdjcNO	01626187505	t
\.


--
-- Data for Name: buet_staff_feedback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buet_staff_feedback (id, complainer_id, route, submission_timestamp, concerned_timestamp, text, trip_id, subject, response, valid) FROM stdin;
45	pranto	3	2024-01-24 07:59:49.727805+06	2024-01-23 00:00:00+06	nsns	\N	{bus}	\N	t
46	pranto	3	2024-01-24 11:38:25.472839+06	2024-01-25 00:00:00+06	hsjsj	\N	{driver}	\N	t
53	pranto	8	2024-02-08 23:22:19.613093+06	2024-02-07 00:00:00+06	\r\nThe staff behavior was very rude and they were very disrespectful towards the passengers, which significantly tarnished the overall experience of the journey. Additionally, their lack of professionalism and disregard for customer satisfaction left much to be desired. Such behavior not only creates discomfort but also undermines the reputation of the service provider. It is essential for the staff to exhibit courteousness and respect towards passengers, fostering a positive and welcoming environment for all travelers.	\N	{staff,driver}	\N	t
\.


--
-- Data for Name: bus; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bus (reg_id, type, capacity, remarks, valid) FROM stdin;
Ba-98-5568	mini	30	\N	t
Ba-71-7930	mini	30	\N	t
Ba-85-4722	normal	60	\N	t
Ba-34-7413	mini	30	\N	t
Ba-24-8518	double_decker	100	\N	t
Ba-22-4326	mini	30	\N	t
Ba-83-8014	mini	30	\N	t
Ba-86-1841	normal	60	\N	t
Ba-20-3066	normal	60	\N	t
Ba-43-4286	mini	30	\N	t
Ba-17-3886	double_decker	100	\N	t
Ba-46-1334	mini	30	\N	t
Ba-63-1146	double_decker	100	\N	t
Ba-97-6734	mini	30	\N	t
Ba-17-2081	double_decker	100	\N	t
Ba-93-6087	mini	30	\N	t
Ba-36-1921	normal	60	\N	t
Ba-35-1461	normal	60	\N	t
Ba-48-5757	mini	30	\N	t
Ba-77-7044	mini	30	\N	t
Ba-69-8288	double_decker	60	\N	t
Ba-12-8888	mini	60	\N	t
Ba-19-0569	double_decker	69	\N	t
BA-01-2345	single_decker	30	Imported from Japan	t
\.


--
-- Data for Name: bus_staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bus_staff (id, phone, password, role, name, valid) FROM stdin;
masud84	01333694280	$2a$12$cZurgNcIGXe4gqk0sUfjZ.SSB//kRpLd6J5LElSo8ZUck2qOR.xo2	driver	Masudur Rahman	t
shahid88	01721202729	$2a$12$LBjDsiOlXyGehr0SB99Bp.r7MJl4rUUmHzoXJDpRYdtk2LKFgOexW	driver	Shahid Khan	t
aminhaque	01623557727	$2a$12$qjHfLEK4l4jhWRdmTrpIVuYLtQ8xbmVvus9u49RvlLmLXsZTdP1S.	driver	Aminul Haque	t
fazlu77	01846939488	$2a$12$bvimHRtXKtdNvntiFID6kuIZQrPM9alZ6seeB5JdVGE396NM44X4O	driver	Fazlur Rahman	t
mahmud64	01328226564	$2a$12$LeFqDxpS9CtUIHMP4NPPLugvhvXt5oZ6f15gWb1d9pk0lB1tjccRW	collector	Mahmudul Hasan	t
shamsul54	01595195413	$2a$12$RLObtVZ.3EQpZy8mEa9Y0.sh6XaFf7sNtLPSc1TWiTBLTQs1G3Zei	collector	Shamsul Islam	t
abdulbari4	01317233333	$2a$12$zi0o5eouMqUWrVZFP42pk.AS9NoG5q37Ps0y93DZCGXE0Y39Eh436	collector	Abdul Bari	t
ASADUZZAMAN	01767495642	$2a$12$NdfLbp1kT8XdXhJJlQ8B0u/47ceKdUGabS6bWRK94Rb1wwvpBm0KW	collector	Asaduzzaman	t
farid99	01835421047	$2a$12$1FgwdZaeUjwy54/s7rgTt.3jpG78CWoc15VoatWk4HF73kYPckDYm	collector	Farid Uddin	t
zahir53	01445850507	$2a$12$D98aELlvMcT1MSCLgiA4bOJyR3N8GTA6c68oH6ZLdpru0rCTjeYx.	collector	Zahirul Islam	t
jamal7898	01308831356	$2a$12$f0dp5gnOaLtA3PHSwmDjFODI3gvdI8eywRyAeOZh5vkKnFKd4sq7u	collector	Jamal Uddin	t
alamgir	01724276193	$2a$12$Mks0vq8VnFE0KQLPPGDHIOckNk0X/Bg0t8ZZY94TBOdUNNFhiVYpa	collector	Alamgir Hossain	t
sohel55	01913144741	$2a$12$i3pmxyB.s/IBCoaAFIrUSeD09geAIbQHBTJ4qXzqfM4xt7U5MbnYq	driver	Sohel Mia	t
mahabhu	01646168292	$2a$12$zLaIZBRQfIL8xGskkRgJKeCUsfDjLnhwpx5octdy2CJfDnR5XGqkW	collector	Code Forcesuz Zaman	t
arif43	01717596989	$2a$12$QXojv2Qi5JWbnHqlXVJ/iOsY5ek1ZzEd8aU7TxvgI0SLHLLebz9su	driver	Arif Hossain	t
azim990	01731184023	$2a$12$OO/7cjbe4RzN46d9fPsVjefASRLtdnNbPuX1AIW3Ant6abmcJJndG	collector	Azim Ahmed	t
altaf78	01711840323	$2a$12$dbWCKqB4wW1.7dOJzjD4EOzVUjBptKXP96WOMEbz2GjQtaqB1Whae	driver	Altaf Mia	t
reyazul	01521564738	$2a$12$pXPW0EWH9ZGeeaGkqGsgaOWbtiaGU77lbd6ClXl29W0YERI5aISWe	collector	Kazi Rreyazul	t
ibrahim	01345435435	$2a$12$6Doi584t7hqxuKy0wARppOK8HR0iyfpP4Uug1rXrubn4F.XMxKdIa	driver	Khondker Ibrahim	t
rahmatullah	01747457646	$2a$12$d/lXs/rJ4QNdctxyii.HJeB91Udj9KMD/mxieQCKJIk8EsUZ1iyjm	driver	Hazi Rahmatullah	t
monu67	01345678902	$2a$12$2Wky7R.kBFFcbFmICBBrle1ePIJsSGiddsKXjUuJao4QWcGKuzJUC	driver	Monu Mia	t
polash	01678923456	$2a$12$ShQOKnRZvD4GW0y7CBKZjuckou.JHsGuZQMxqWC1/mEqIgg539vJe	driver	Polash Sikder	t
rafiqul	01624582525	$2a$12$scfPmCg7cWkNgdqXyHbbcOMb63sevkjnRfvQstfD7UbVwANrCes..	driver	Rafiqul Hasan	t
nizam88	01589742446	$2a$12$/VqawsZWgybw6H5TzKiNHukVK8Irl6bvh9jPEonLrOzqOx1wIdRj2	driver	Nizamuddin Ahmed	t
kamaluddin	01764619110	$2a$12$fQMqPhKHPiUZzJVudN8NfeBlUijPF1BWTf3wG2sZmeOa8om5NrVaS	driver	Kamal Uddin	t
shafiqul	01590909583	$2a$12$VghRKN9mDuPmugby/FlLteeXh0o9ADCUUzKzvMNYW.saZcJyJCHHi	driver	Shafiqul Islam	t
abdulkarim6	01653913218	$2a$12$XZ6W.7npe4btQ2Sb9.MZLel0Tm19UEQiu8mGimcpwSZq5gxEgRGcK	driver	Abdul Karim	t
imranhashmi	01826020989	$2a$12$vMt9Ace7ZQVOVwz/GlCudeO7nsGu.BbnMhJYtQIHyAEO1k/R2lE2q	driver	Imran Khan	t
jahangir	01593143605	$2a$12$5yxa3ETfLnja1PLWozr0jOUMtLEcejixzF6Ipcu3OI1wVxFHMmAES	driver	Jahangir Alam	t
rashed3	01410038120	$2a$12$W0aYTqNWuVIqISl9KnTEiu/am359ekUHnPp1uhuBT.NEf4R4ktOeu	driver	Rashedul Haque	t
nazrul6	01699974102	$2a$12$qrAfe1coHKyu1eXjbbNyyOoyuEtn3TDAhz9CqtD6isQmhOGAW2M0S	driver	Nazrul Islam	t
rashid56	01719898746	$2a$12$/M1gpTDTW1CuI8FUm5bLu.JDb/uzkM4Hjm0jedZzYeH7784kFdd5a	collector	Rashidul Haque	t
sharif86r	01405293626	$2a$12$rsIzJ3Z7GVq3aBCXvV4DR.DviJjofzQvbnqouQxfNgdDSaPal3dKi	collector	Sharif Ahmed	t
mahbub777	01987835715	$2a$12$f.x9rAKZq3MGyzf2gaK3J.huUgzPe6LryMtCGXnX7eHD8tvnr1REa	collector	Mahbubur Rahman	t
khairul	01732238594	$2a$12$8v5WT0tV.xusChomV33rWu4orPcFqUTA6vzR13c4t/b0Qj9ktNKEW	collector	Khairul Hasan	t
siddiq2	01451355422	$2a$12$EiyVFWdeSzBbMWESfoMdCeHsAubI3FkppfJ6Rt8xTSt2ZpmvxUtyu	collector	Siddiqur Rahman	t
nasir81	01481194926	$2a$12$Y0FGv2TXIJlVCChaRRvtf.T9Q3jaXZcQhAie4d1vKtDPSaWwZopFa	collector	Nasir Uddin	t
altaf	01933002218	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	driver	Altaf Hossain	t
\.


--
-- Data for Name: inventory; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventory (id, name, amount, rate, valid) FROM stdin;
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
55	1905067	2024-02-05 17:46:50.462166+06	shurjopay	65c0caa9	8
56	1905067	2024-02-05 23:38:50.581933+06	shurjopay	65c11d29	15
63	1905077	2024-02-08 01:00:09.516477+06	shurjopay	65c3d338	50
64	1905077	2024-02-08 01:00:25.26249+06	shurjopay	65c3d348	20
65	1905084	2024-02-08 15:26:16.448634+06	shurjopay	65c49e37	37
66	1905084	2024-02-08 15:53:17.372961+06	shurjopay	65c4a48c	555
67	1905077	2024-02-08 17:54:30.398433+06	shurjopay	65c4c0f5	500
68	1905077	2024-02-08 17:57:22.840182+06	shurjopay	65c4c1a1	26
69	1905067	2024-02-08 18:03:34.095767+06	shurjopay	65c4c315	50
\.


--
-- Data for Name: requisition; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.requisition (id, requestor_id, source, destination, subject, text, "timestamp", approved_by, bus_type, valid) FROM stdin;
38	pranto	ECE BUET 	RUET	personal	\r\nWe are requesting transportation for the "RUET - Inter University Programming Contest." Considering the distance and potential traffic, we need a car for our team's convenience and flexibility. A car will ensure a swift and comfortable journey, allowing us to reach the contest venue promptly. Additionally, a microbus is necessary to accommodate our team and any equipment required for the event. The spaciousness and versatility of a microbus will enable us to travel together comfortably and efficiently, ensuring that we arrive at the competition fully prepared and ready to participate effectively.	2024-02-15 10:30:00+06	\N	{car,micro-12}	t
35	pranto	ECE Campus, Dhaka	KUET Campus , Khulna		For the upcoming IUPC contest , we need a bus . 	2024-02-09 10:30:00+06	\N	{micro-15}	t
36	pranto	ECE BUET	SUST		IUPC	2024-02-10 08:30:00+06	\N	{micro-15}	t
37	pranto	ECE Campus , Dhaka 	Agrani Bank LTD , Mirpur 	BRTC	\r\nA microbus is necessary for our visit to Agrani Bank in Mirpur due to several reasons. Firstly, a microbus offers sufficient space to accommodate our team comfortably, ensuring everyone can travel together efficiently. Secondly, considering the distance and potential traffic conditions, a microbus provides the flexibility and maneuverability required for navigating urban routes, ensuring a smooth and timely journey. Additionally, a microbus allows us to transport any necessary equipment or materials for our learning session, ensuring we have everything we need on-site. Overall, the convenience, comfort, and practicality of a microbus make it the ideal transportation option for our educational visit to Agrani Bank.	2024-02-10 08:30:00+06	\N	{micro-8}	t
\.


--
-- Data for Name: route; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.route (id, terminal_point, points, valid, predefined_path) FROM stdin;
1	Uttara	{1,2,3,4,5,6,7,8,9,10,11,70}	t	\N
8	Mirpur 12	{64,65,66,67,68,69,70}	t	\N
2	Malibag	{12,13,14,15,16,70}	t	\N
3	Sanarpar	{17,18,19,20,21,22,23,24,25,26,70}	t	\N
4	Badda	{27,28,29,30,31,32,33,34,35,70}	t	\N
6	Mirpur 2	{41,42,43,44,45,46,47,48,49,70}	t	\N
7	Airport	{50,51,52,53,54,55,56,57,58,59,60,61,62,63,70}	t	\N
5	Mohammadpur	{36,37,38,39,40,70}	t	{"(23.7277005,90.3915536)","(23.7272151,90.3917681)","(23.7267545,90.3918323)","(23.7262922,90.3919235)","(23.7261866,90.3914254)","(23.726548,90.3908094)","(23.7270001,90.3901624)","(23.7272766,90.3897504)","(23.727589,90.3893203)","(23.7281956,90.3888225)","(23.7285256,90.3884753)","(23.7288433,90.3881179)","(23.7292273,90.3878095)","(23.7323337,90.3854034)","(23.732539,90.3849662)","(23.7329863,90.3848359)","(23.7334396,90.3847276)","(23.7338888,90.384657)","(23.7343437,90.3845413)","(23.7347989,90.3843992)","(23.7352286,90.3842399)","(23.735816,90.384099)","(23.7362957,90.3839276)","(23.7368577,90.3838719)","(23.7375922,90.3837157)","(23.738055,90.3836674)","(23.7385034,90.3835617)","(23.7389441,90.3833578)","(23.7393894,90.3832737)","(23.7394432,90.3827815)","(23.7393307,90.3823006)","(23.739173,90.3814846)","(23.7390219,90.3806199)","(23.7388026,90.3796488)","(23.7386602,90.3788551)","(23.738571,90.3783634)","(23.7384856,90.3778672)","(23.7383949,90.3773851)","(23.7383121,90.3768871)","(23.7382914,90.3763953)","(23.7385267,90.3759654)","(23.7389219,90.3756781)","(23.7393427,90.3754623)","(23.7397452,90.3751643)","(23.7402104,90.3750361)","(23.7408624,90.3747133)","(23.7413335,90.3744239)","(23.7420379,90.3740933)","(23.7425203,90.3737572)","(23.7431309,90.373406)","(23.7436047,90.3730969)","(23.7441206,90.3727575)","(23.7446899,90.3723246)","(23.7450767,90.372024)","(23.7454949,90.3717077)","(23.7459099,90.3714097)","(23.7463337,90.3711167)","(23.7467796,90.3708159)","(23.7471771,90.3705583)","(23.7475997,90.3702801)","(23.7480531,90.370003)","(23.7484648,90.3697361)","(23.7488765,90.3695191)","(23.74927,90.3692409)","(23.7498073,90.3689208)","(23.7502894,90.3685247)","(23.7507021,90.3682338)","(23.7511345,90.3679947)","(23.7514487,90.3676382)","(23.7518593,90.3673785)","(23.7523424,90.3670369)","(23.7527357,90.3667451)","(23.7530168,90.3663358)","(23.7534395,90.3658951)","(23.7537416,90.3655136)","(23.7540984,90.3651801)","(23.7544818,90.3646903)","(23.755042,90.3642056)","(23.7554833,90.3643758)","(23.7560664,90.3642333)","(23.7566818,90.3640182)","(23.7572545,90.3638196)","(23.7578518,90.3635931)","(23.7583087,90.3635162)","(23.7584806,90.3639753)"}
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
5c_XFad1W2RkNeAsfNnYqTKBBc5e1IVs	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-08T08:58:03.461Z","httpOnly":false,"path":"/"},"userid":"69","user_type":"student"}	2024-03-08 15:52:23
EABHxtHnQoMz8f3ADl9NZNfa3HiF2jnu	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-09T13:12:15.945Z","httpOnly":false,"path":"/"},"userid":"69","user_type":"student"}	2024-03-09 19:12:16
gfv3H1t3cCR2bKinVsYjdNVGY_rWkTKW	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-10T10:04:46.675Z","httpOnly":false,"path":"/"},"userid":"rashed3","user_type":"bus_staff","fcm_id":"c2fEqy5oS4mwlwdEY3hHP5:APA91bEJev3VGUUf4XUVnn_1ILZOnF5_jdgnPrHgH63kgQXUhLay5pLQkrUJiMh1LEVMPxZPc2NeV4gc2jRKTDOlnk1W3FdLH9xNnRe1j4RKJv920cB81v3AuU6XgXA9iXE6UYME_-02"}	2024-03-10 16:08:48
7PXonsyG1n9kwiFSGdOsRz3sR1nhkem_	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-09T06:54:41.502Z","httpOnly":false,"path":"/"},"userid":"1905084","user_type":"student"}	2024-03-09 15:55:55
ygTjflvQR-MxK5zON19uFjYFf3r7GB3e	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-10T05:45:29.616Z","httpOnly":false,"path":"/"},"userid":"1905077","user_type":"student","fcm_id":"dhmD5nUITji12jjNX_XSrM:APA91bFYxD_EUCmXI73-_0pJ88flk5Q5f0a5sfbpifYHy2Xyk9JxwRCPpbtz1Gsa9vuO_rqQCtMNS_LUNh1QoUAvC7sAHf_rGrtuRew_Vz3DPkWDwwe0xseO2XjEeL7OGU1Z7debNSFU"}	2024-03-10 11:45:48
UjDtw-DZ9igZjn1sek_yeEmuZi1X5CzP	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-10T15:05:00.224Z","httpOnly":false,"path":"/"},"userid":"1905067","user_type":"student","fcm_id":"dqEQguDpTzeKOOQsd7x1uV:APA91bGnhjPXmkiNT2Z7JJ5Twzd92YHC-6iBehcbwbOPhp1nGVz-5fIONTk-7ZlJu9s16AfRovu5Nrjb81xLPUfOXTIr_2iWhRi7jnSRnlakRXBPZPx9t68l1GulC8QEYlRG3jz-o-bi"}	2024-03-10 21:05:04
DBqWajQKJpufOP78sbaT4QpuH61VUW9L	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-09T18:56:39.171Z","httpOnly":false,"path":"/"},"userid":"69","user_type":"student"}	2024-03-10 00:56:41
H-6mJmL_46syCeM28cqZwEeRmglXJVLt	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-09T12:59:07.445Z","httpOnly":false,"path":"/"},"userid":"69","user_type":"student"}	2024-03-09 18:59:08
uVlNTH_80XNmWbzvZfgflMZo40syxfyl	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-10T18:53:21.564Z","httpOnly":false,"path":"/"},"userid":"1905084","user_type":"student","fcm_id":"dVj_grVZT82cpXtN9RZUEr:APA91bHjgnFIoOTDcMO4h6Ma7dXNbBQMVbEkMnjy_8rBhPyfTJQwmxASrat1UPDyc5zLoaRIOR57gMVZH9G5LyeuIjcGBmMgkNE-rCsDni_vkPh1i-0xlwzaiYeoVz3L9KxuCrluaiuV"}	2024-03-11 01:26:00
COQt6pKLTGJsOXy3K791d5giNacXF3rt	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-09T13:01:13.922Z","httpOnly":false,"path":"/"},"userid":"1905067","user_type":"student"}	2024-03-09 19:01:14
N4vUWlJusFupBIU53B09PGzqQ3FPosnw	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-10T15:16:51.920Z","httpOnly":false,"path":"/"},"userid":"1905067","user_type":"student"}	2024-03-10 21:22:44
W3qtopROhPb6SD1MrG_7azcW_f3Ho97z	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-09T13:04:38.637Z","httpOnly":false,"path":"/"},"userid":"1905067","user_type":"student"}	2024-03-09 19:04:39
oGtJfT06UkkI011BLr_DEZ5SYOUOFUiB	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-09T13:06:34.868Z","httpOnly":false,"path":"/"},"userid":"69","user_type":"student"}	2024-03-09 19:06:35
Vd8j0eSwo0BHpjdvcnyQxFAETvdnjzpH	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-08T11:55:00.954Z","httpOnly":false,"path":"/"},"userid":"1905067","user_type":"student"}	2024-03-10 16:06:58
luH1YPdqIQ1nKydBMdZfKviUN69pcYS0	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-03-09T16:06:16.993Z","httpOnly":false,"path":"/"},"userid":"1905077","user_type":"student"}	2024-03-10 11:06:19
\.


--
-- Data for Name: station; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.station (id, name, coords, adjacent_points, valid) FROM stdin;
8	Old Airport 	(23.77178659908652,90.38957499914268)	\N	t
1	College Gate	(23.769213162447304,90.36876120662684)	\N	t
2	Station Road	(23.892735315562756,90.40197068534414)	\N	t
3	Tongi Bazar	(23.88427608752206,90.40045971191294)	\N	t
4	Abdullahpur	(23.87980639062533,90.40118222387154)	\N	t
5	Uttara House Building	(23.873819697344935,90.40053785728188)	\N	t
6	Azampur	(23.86785298269277,90.40022657238241)	\N	t
7	Shaheen College	(23.775547826528047,90.39189035378897)	\N	t
9	Ellenbari	(23.76522951056849,90.38907568606375)	\N	t
10	Aolad Hossian Market	(23.762978573175356,90.38917778985805)	\N	t
11	Farmgate	(23.75830991006695,90.39006461196334)	\N	t
12	Malibag Khidma Market	(23.749129653669698,90.41981844420462)	\N	t
13	Khilgao Railgate	(23.74422274202347,90.42642485418273)	\N	t
14	Basabo	(23.739739562565465,90.42750217562016)	\N	t
15	Bouddho Mandir	(23.736287102644095,90.42849412575818)	\N	t
16	Mugdapara	(23.73125402135349,90.42847070671291)	\N	t
17	Sanarpar	(23.694910069706566,90.49018171222788)	\N	t
18	Signboard	(23.69382820912737,90.48070754228206)	\N	t
19	Saddam Market	(23.6930333006468,90.47294821509882)	\N	t
20	Matuail Medical	(23.694922870152688,90.46662805325313)	\N	t
21	Rayerbag	(23.699452593105473,90.45714520603525)	\N	t
22	Shonir Akhra	(23.702759892542936,90.45028970971552)	\N	t
23	Kajla	(23.7056566136023,90.4442670782193)	\N	t
24	Jatrabari	(23.71004890888318,90.43452187613019)	\N	t
25	Ittefak Mor	(23.721613399553892,90.42134094863007)	\N	t
26	Arambag	(23.73148111199774,90.42083500748528)	\N	t
27	Notun Bazar	(23.797803911606113,90.42353036139312)	\N	t
28	Uttor Badda	(23.78594006738361,90.42564747234172)	\N	t
29	Moddho Badda	(23.77788437830488,90.42567032546067)	\N	t
30	Merul Badda	(23.772862356779285,90.42552102012964)	\N	t
31	Rampura TV Gate	(23.765717111761024,90.42185514176059)	\N	t
32	Rampura Bazar	(23.761225700270263,90.41929816771406)	\N	t
33	Abul Hotel	(23.754280372386287,90.41532775209724)	\N	t
34	Malibag Railgate	(23.74992564121926,90.41283077901616)	\N	t
35	Mouchak	(23.746596017920087,90.41229675666234)	\N	t
36	Tajmahal Road	(23.763809074127288,90.36564046785911)	\N	t
37	Nazrul Islam Road	(23.757614175962193,90.36241335180047)	\N	t
39	Dhanmondi 15	(23.744501003619725,90.37244046931268)	\N	t
40	Jhigatola	(23.73909098406254,90.37553336535188)	\N	t
41	Mirpur 10	(23.80694289074129,90.3685711078533)	\N	t
42	Mirpur 2	(23.80498118040957,90.36328393651736)	\N	t
43	Mirpur 1	(23.798497327205652,90.35316121745808)	\N	t
44	Mirpur Chinese	(23.794642294364998,90.35335323466074)	\N	t
45	Ansar Camp	(23.79095839297597,90.35375343466058)	\N	t
46	Bangla College	(23.78478514989056,90.35379372859546)	\N	t
47	Kallyanpur	(23.777975490889016,90.36112130222347)	\N	t
48	Shyamoli Hall	(23.77501389359074,90.3654282978599)	\N	t
49	Shishumela	(23.77298522787119,90.3673447413414)	\N	t
50	Rajlokkhi	(23.86427626854673,90.4001008267417)	\N	t
51	Airport	(23.852043584305772,90.40747424854275)	\N	t
52	Kaola	(23.84578900317074,90.41256570948558)	\N	t
53	Khilkhet	(23.829001350312897,90.41999876535472)	\N	t
54	Bishwaroad	(23.821244902976005,90.4184231223024)	\N	t
55	Sheora Bazar	(23.818753739058263,90.41486259303835)	\N	t
56	MES	(23.81686575326826,90.40596761411776)	\N	t
57	Navy Headquarter	(23.802953981274726,90.4023678965428)	\N	t
58	Kakoli	(23.79503254223975,90.40088706906629)	\N	t
59	Chairman Bari	(23.78955650718996,90.40011589790265)	\N	t
60	Mohakhali	(23.77799128256197,90.39735858707148)	\N	t
61	Nabisco	(23.769576184918215,90.40101562859505)	\N	t
62	Satrasta	(23.75740990168624,90.39900644208478)	\N	t
63	Mogbazar	(23.748637341330323,90.40366410668703)	\N	t
64	Mirpur 11	(23.815914422939255,90.36613871454468)	\N	t
65	Pallabi Cinema Hall	(23.819566365373973,90.36516682668837)	\N	t
66	Kazipara	(23.797147561971236,90.37281478255649)	\N	t
67	Sheorapara	(23.790388161465135,90.37570727092245)	\N	t
68	Agargaon	(23.777478142723012,90.38031962673897)	\N	t
69	Taltola	(23.783510519116227,90.37865196128236)	\N	t
70	BUET	(23.72772109504178,90.39169264466838)	\N	t
38	Shankar Bus Stand	(23.750650301853547,90.36821656808486)	\N	t
\.


--
-- Data for Name: student; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student (id, phone, email, password, default_route, name, default_station, valid) FROM stdin;
1905084	01729733687	jalalwasif@gmail.com	$2a$12$MvqL5LGR/K1VVJpev3wxoO/XKoS/EP.D/Zch1p8eAmOKcQ.WZIg7u	5	Wasif Jalal	37	t
1905105	01976837633	shahriarraj121@gmail.com	$2a$12$dCICg8hcWHYCvnF.RNKDi.8oM3vGUZEDXYS2pNL4nMIM8Gn4h2V4e	5	Shahriar Raj	36	t
1905077	01284852645	nafiu.rahhman@gmail.com	$2a$12$2rrw/Jyeq/XSu/jLXlibmu.XqaYBYeb2YooQW2CBxNKSUKj5cSv2a	5	Nafiu Rahman	36	t
69     	01234567890	nafiu.grahman@gmail.com	$2a$12$4pDhPGmCJDOonyuCQMAQIudSQn8CFXvZY3xDaHemv9REetifbVSKe	5	Based Rahman	38	t
82     	01521564738	kazireyazulhasan@gmail.com	$2b$10$TphyE44V6H683vNhMFY9x.6tb1aj1x5omFa7CtE2J/86BP3jnTA4S	5	Kazi Reyazul Hasan	14	t
88     	01521564738	kazireyazulhasan@gmail.com	$2b$10$DmxlF076lspjifV0Gdh.ue3O.h7YyegFTOVXx2vuFIQ3Djfng8SOG	2	Musarrat	6	t
1905058	01811111111	sadif@gmail.com	$2a$12$tXuYcuW712UpgJiFY.Rj5euinUdAPVIfIfpUnyeDDh0rZmPby6/Vu	5	Sadif Ahmed	36	t
1905069	01234567894	mhb69@gmail.com	$2a$12$uFsNORh9NT51ORsUacMDi.G7XfzrmTbSTcsDPRJvdIhEN2kBqIdmO	1	Mashroor Hasan Bhuiyan	7	t
1905082	01521564748	kz.rxl.hsn@gmail.com	$2a$12$PJ1xmj9l2Ab6AT8pnvuzEe06fum1yCkUD5gv.2M0ehBbmhmR0GuY6	7	Kazi Reyazul Hasan	12	t
1905088	01828282828	mubasshira728@gmail.com	$2a$12$qJv62Y58wXrnJKegl.7FIuD0YfwvwFWqwSq1rBiOShMgtFOaxJr8a	6	Mubasshira Musarrat	47	t
1905067	01718069985	sojibxaman439@gmail.com	$2a$12$sLZ8yzBa7fo3heCPgdni8Oc9Iv3.hIwaZjcx8cV6y8Rn4pA04jU8.	4	MD. ROQUNUZZAMAN SOJIB	27	t
\.


--
-- Data for Name: student_feedback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_feedback (id, complainer_id, route, submission_timestamp, concerned_timestamp, text, trip_id, subject, response, valid) FROM stdin;
3	1905084	4	2023-09-06 11:25:48.287028+06	2023-09-01 00:00:00+06	ieieieiehdjdkdks	\N	{bus,staff}	\N	t
4	1905084	3	2023-09-06 11:36:34.942567+06	2023-09-03 00:00:00+06	jdjdkkw didjd	\N	{bus}	\N	t
6	1905084	\N	2023-09-06 11:41:12.132757+06	\N	hhjkvgg	\N	{other}	\N	t
7	1905084	5	2023-09-06 13:17:05.786283+06	2023-09-03 00:00:00+06	হালা আমারে ভাংতি দেয় নাই 😡	\N	{staff}	ভাই টিকেট না বিক্যাশে কিনসেন? কন্ডাক্টরের কাছে ভাংতি চান কেন?	t
8	69	3	2023-09-06 21:01:31.633662+06	2023-09-01 06:00:00+06	The time table should be changed. So unnecessary to start journey at 6:15AM in the morning. 	\N	{bus}	Thank you for your request. It has automatically been ignored.	t
10	69	8	2023-09-06 23:27:02.239861+06	2023-09-01 06:00:00+06	driver ashrafur rahman amar tiffin kheye felse	\N	{staff}	\N	t
11	1905084	3	2023-09-07 03:29:51.973152+06	\N	trrgy	\N	{bus}	\N	t
12	1905084	3	2023-09-07 04:38:22.389025+06	\N	seat bhanga	\N	{bus}	\N	t
13	69	3	2023-09-07 11:00:31.772593+06	2023-09-01 00:00:00+06	baje staff	\N	{staff}	\N	t
16	1905067	6	2023-09-07 11:12:52.902353+06	\N	Bus didn't reach buet in time. Missed ct	\N	{bus}	\N	t
17	1905067	4	2023-09-07 11:13:30.087775+06	2023-08-24 00:00:00+06	Staff was very rude	\N	{staff}	\N	t
18	1905067	3	2023-09-07 11:14:10.821911+06	2023-09-04 00:00:00+06	Driver came late	\N	{driver}	\N	t
20	1905067	7	2023-09-07 11:18:51.84041+06	\N	Can install some fans	\N	{other}	\N	t
21	1905088	5	2023-09-07 11:25:20.058267+06	2023-09-05 00:00:00+06	Helper was very rude. shouted on me	\N	{staff}	\N	t
22	1905088	6	2023-09-07 11:26:39.318946+06	2023-09-06 00:00:00+06	Bus left the station earlier than the given time in the morning without any prior notice	\N	{bus}	\N	t
23	1905088	1	2023-09-07 11:27:26.44088+06	2023-08-16 00:00:00+06	Too crowded. Should assign another bus in this route	\N	{other}	\N	t
24	69	5	2023-09-07 11:34:00.003955+06	\N	vai amare gali dise ,oi bus e uthum nah ar	\N	{staff}	\N	t
25	1905077	5	2023-09-07 11:43:47.455913+06	2023-09-05 00:00:00+06	bad seating service	\N	{staff}	\N	t
15	1905067	5	2023-09-07 11:12:05.993256+06	2023-08-08 00:00:00+06	way too many passengers	\N	{other}	Sorry but we are trying to expand capacity	t
19	1905067	2	2023-09-07 11:14:55.781888+06	\N	Bus left the station before time in the morning	\N	{bus}	According to our data the bus left in correct time, if you would like to take you claim further then pls contact the authority with definitive evidence	t
26	1905077	6	2023-09-07 11:44:13.981407+06	2023-09-02 00:00:00+06	no fan in bus	\N	{driver}	we are planning to install new fans next semester, pls be patient till then.	t
27	1905077	5	2023-09-07 12:00:58.617135+06	2023-09-05 00:00:00+06	rough driving	\N	{staff}	\N	t
28	1905088	5	2023-09-07 14:39:49.325426+06	2023-09-06 00:00:00+06	rude driver	\N	{driver}	\N	t
29	1905084	5	2023-09-07 18:31:43.400612+06	2023-09-04 00:00:00+06	no refreshments offered 😤	\N	{other}	\N	t
30	1905084	5	2023-09-07 18:51:09.219167+06	2023-09-06 00:00:00+06	hdhe	\N	{bus}	\N	t
31	1905084	5	2023-09-08 00:42:30.790952+06	2023-09-07 00:00:00+06	Did not stop when I asked to	\N	{driver}	\N	t
32	1905084	5	2023-09-09 09:12:07.12405+06	2023-09-07 00:00:00+06	bhanga bus. sojib jhamela kore window seat niye	\N	{bus}	\N	t
33	1905077	6	2023-09-11 16:51:13.450342+06	2023-09-11 00:00:00+06	বাসে চড়তে ভাল্লাগে না	\N	{other}	\N	t
34	1905077	1	2023-09-15 11:46:26.199246+06	2023-09-05 00:00:00+06	Dangerous driving 	\N	{staff}	\N	t
35	1905077	1	2023-09-15 11:46:46.502356+06	2023-09-05 00:00:00+06	Dangerous driving 	\N	{staff}	\N	t
36	1905067	1	2024-01-04 20:15:34.335892+06	2023-10-05 11:48:00+06	The driver was driving without any caution. He almost hit a bike on the road. 	\N	{driver}	\N	t
37	1905067	1	2024-01-04 20:16:01.78843+06	2023-10-05 11:48:00+06	The driver was driving without any caution. He almost hit a bike on the road. 	\N	{driver}	\N	t
38	1905067	1	2024-01-06 12:38:25.721532+06	2023-10-05 11:48:00+06	The driver was so bad.	\N	{driver}	\N	t
39	1905067	1	2024-01-06 13:14:21.261369+06	2023-10-05 11:48:00+06	bad driver	\N	{driver}	\N	t
40	69	5	2024-01-23 17:29:48.807233+06	2024-01-23 00:00:00+06	hdjeikek	\N	{driver,staff}	\N	t
41	1905067	8	2024-01-23 17:32:26.99375+06	2024-01-19 00:00:00+06	mok marisil	\N	{staff}	\N	t
47	69	2	2024-01-29 09:42:23.279531+06	2024-01-23 00:00:00+06	Jhamela hoise	\N	{driver}	\N	t
48	1905077	5	2024-01-31 15:11:46.467135+06	2024-01-17 00:00:00+06	pocha shobai bus er	\N	{driver}	\N	t
9	69	1	2023-09-06 21:04:17.110769+06	2023-09-05 06:00:00+06	1984: Possibly the most terrifying space photograph ever taken. NASA astronaut Bruce McCandless floats untethered from his spacecraft using only his nitrogen-propelled, hand controlled backpack called a Manned Manoeuvring Unit (MMU) to keep him alive.	\N	{other}	id ki kaj kore kina dekhar jonno	t
2	1905084	3	2023-09-06 11:25:01.426082+06	\N	ieieieie	\N	{bus}	kaj kore kina, na korle boka dibe ou nu	t
14	1905067	6	2023-09-07 11:10:55.061921+06	2023-09-05 00:00:00+06	Bus changed its route because of a political gathering & missed my location. 	\N	{bus}	amra busbudy banaisi ki jonno	t
49	1905105	5	2024-02-06 12:31:17.667951+06	2024-02-01 00:00:00+06	The roads were bad.	\N	{other}	\N	t
50	1905105	5	2024-02-06 12:33:29.114251+06	2024-01-20 00:00:00+06	The bus was late. 	\N	{driver,bus}	\N	t
51	1905105	5	2024-02-06 12:35:44.256871+06	2024-01-27 00:00:00+06	The bus left without me 	\N	{driver,bus,staff}	\N	t
52	1905105	6	2024-02-07 16:57:05.981879+06	2024-02-07 00:00:00+06	Bus is full of mosquitoes !!!!!!!!!!!¡!🦟	\N	{bus}	\N	t
\.


--
-- Data for Name: student_notification; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_notification (id, user_id, text, "timestamp", is_read) FROM stdin;
\.


--
-- Data for Name: ticket; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ticket (student_id, trip_id, purchase_id, is_used, id, scanned_by) FROM stdin;
1905077	\N	63	f	bf629f67-42d2-4825-9d05-0c4bfd0517c7	\N
1905084	\N	51	f	cbda569b-4da6-454d-a7d9-c98308654a08	\N
1905084	\N	51	f	5780cb12-a125-4ed7-ae41-0f392e2c2c34	\N
1905084	\N	51	f	3ea017a7-f998-4307-80e9-c731d7d88868	\N
1905084	\N	51	f	1c89c3fc-b4d9-433f-9e63-5f4864ee6f60	\N
1905084	\N	51	f	14cd2a03-0358-4056-a4ed-1063de7bcb6d	\N
1905084	\N	51	f	bd08b692-6ecc-4d15-a4b1-0082375aa9d9	\N
1905084	\N	51	f	757a6b94-1bf7-483a-b95f-1ba5aea0cf4a	\N
69     	\N	52	f	3ce03833-4888-4c3d-859f-0e9aca093eff	\N
69     	\N	52	f	eeaba65b-9455-4581-b5ff-ba49ca7915fd	\N
69     	\N	52	f	ce0146d6-714a-4327-bd7b-6003984c1a56	\N
69     	\N	52	f	ebede49f-fdcb-4ac4-a6ff-7eb95ef3fd31	\N
69     	\N	52	f	12cd7519-b638-46a5-b9da-0c900d506572	\N
69     	\N	52	f	efbb9a55-61d4-4630-b556-f0ee8ad9e1a6	\N
69     	\N	52	f	fdb17c28-a37a-4d2f-afa8-b6c91a96433d	\N
69     	\N	52	f	e05b75c1-ff87-4d3f-a382-63bc706063ab	\N
1905077	\N	54	f	4a0d345a-eff3-4821-a37c-68107a378201	\N
1905077	\N	54	f	bb591671-ae91-4998-ab2f-b8bc6d0c0122	\N
1905077	\N	54	f	6d75dca8-24f9-4005-bf80-4cec9ff200a2	\N
1905077	\N	54	f	de74f2b4-549f-4f12-912d-eb178cffcccf	\N
1905067	1539	53	t	ef57d389-4025-413c-8a8b-6b58f6554cd9	\N
1905067	1539	53	t	9e872f9f-2441-4511-ab93-2d6b086e2a09	\N
1905067	1786	53	t	61d85db4-de4e-462c-8177-17808603a033	\N
1905067	1786	53	t	4d7f86e4-b7a8-4129-ba28-eddd5a2ef24e	\N
1905067	1930	53	t	22dcd7cb-b7e0-4ea0-8a80-0ab6de5c0659	\N
1905084	\N	51	f	33dbe35f-2d62-47d3-9ad2-a65708e85fb8	\N
1905067	2108	53	t	d004363b-770f-4cee-94db-b9cc072d5e7e	\N
1905084	2150	51	t	1f176532-22a1-46e3-bd99-bfa9cd299869	arif43
1905077	\N	63	f	73e01a5e-dd9e-4fa9-bb57-ac1b7fdbf11a	\N
1905084	2078	51	t	34d6cf97-a2e9-4e04-8c85-6e31eb892b22	ibrahim
1905084	2150	51	t	c99b89c8-c00d-4c81-a5ba-5944c76b1c5a	arif43
1905067	\N	55	t	30307e1f-0db5-4f95-a649-d9edb2945de7	\N
1905067	2131	55	t	22d3ce6a-bf26-419f-9d3d-9ad4611fe192	\N
1905067	2131	55	t	a137e144-8b29-4815-b626-56aa3799379f	\N
1905067	2131	55	t	6af6d1cf-d15a-44c1-97c8-e86b89b8f6ba	\N
1905067	2131	55	t	f48aaf7e-6e6e-49fe-924d-f3c7e2ebfb29	\N
1905067	2131	55	t	c3662f59-339c-444e-b9ac-30ced7a6a2cc	\N
1905067	\N	56	f	4f920802-4bea-4e09-b697-49148fb8cc93	\N
1905067	\N	56	f	afbdf8ae-48fc-4dec-a3ae-651d02a9fc62	\N
1905067	\N	56	f	a3604a4e-7e51-4dd6-afd9-15e6fb81e63b	\N
1905067	\N	56	f	68c061d9-4b11-4462-8390-72e17fa7db40	\N
1905067	2131	55	t	ad248bbe-4c08-47e0-a037-3169fb2b87d0	\N
1905067	2131	55	t	2258ada0-bcc4-4f7e-90f2-b27b4d541ab4	\N
1905067	2131	56	t	703f7f64-3509-44e5-8c7e-cab172a60736	\N
1905067	2131	56	t	693a175d-5ac8-4048-8e4f-c3ddb935a119	\N
1905067	2131	56	t	fa8a3a54-ed8f-4472-b66b-f26dbbdf745c	\N
1905067	2131	56	t	5fca185f-f165-4ffa-bbf6-1bfab25564b4	\N
1905067	2131	56	t	6d9d5d28-ad4a-411f-8f0c-83f6456d5fa6	\N
1905067	2131	56	t	b384c84c-f59f-4269-9b9c-7eb6411a64d7	\N
1905067	2131	56	t	f8e95c3f-47ae-4a7a-a6a0-7f3cba56e50c	\N
1905067	2131	56	t	acb69419-894e-4d4b-a96c-4f22cb66f349	\N
1905067	2131	56	t	cad334ae-0747-4229-a4ee-5638718d9844	\N
1905067	2131	56	t	ba3920be-7dfc-4847-ba74-1487fe8f7eb4	\N
1905067	2131	56	t	bce284e8-7e9d-42d7-9198-8c7a24343bd4	\N
1905077	\N	63	f	a7d0c1a3-b8e9-4f2b-b698-6eb2e21e42a0	\N
1905077	\N	63	f	c5d59f7d-8526-4739-8510-a2fe4a0ab4e1	\N
1905077	\N	63	f	acfbe4cc-f0b6-4bac-862d-afffcdbc3fe4	\N
1905077	\N	63	f	2064bfbd-af90-4f3f-bdfc-a8cfb7ca0c32	\N
1905077	\N	63	f	4579a4a2-6a4d-4e10-b996-1b3a94230d72	\N
1905077	\N	63	f	31dd2c6e-1459-409b-a81f-f5decea22ebc	\N
1905077	\N	63	f	f20327ce-191a-45e2-a330-cde7455d736f	\N
1905077	\N	63	f	792fc650-16b0-407b-8429-b9a9f17e2d8e	\N
1905077	\N	63	f	40d05ab2-7c6a-4dca-b661-73c8af48f06c	\N
1905077	\N	63	f	4b99248b-c085-4fb4-9631-fbe65e7d46ff	\N
1905077	\N	63	f	b11d9d5e-d525-41f9-a0e1-5bbf2a13986a	\N
1905077	\N	63	f	ce7b8124-9240-4522-8ff8-e00817d5d89c	\N
1905077	\N	63	f	e303be2b-a00d-4286-8003-6d12f23b0dc7	\N
1905077	\N	63	f	c192f5f9-d765-4754-ab5a-b652c434cd7d	\N
1905077	\N	63	f	35f00ff9-24cb-48b8-9738-e6c8abc1c3c1	\N
1905077	\N	63	f	f4c2594b-11d4-4cf9-a932-381c9b69196b	\N
1905077	\N	63	f	bfd509b1-211f-458c-88da-ba878c17eed2	\N
1905077	\N	63	f	3ecf96f5-f946-4ef4-9661-237e52563a94	\N
1905077	\N	63	f	f08520c7-3909-46a1-99db-865a8c2a1e03	\N
1905077	\N	63	f	da27dd9d-1350-422a-86ed-c639e3d3e84e	\N
1905077	\N	63	f	e5c57481-e303-47de-a091-2bc51d97145b	\N
1905077	\N	63	f	5f3d74b6-3754-44ad-96c1-5510d961354f	\N
1905077	\N	63	f	a676b7ab-1265-4acd-a71c-e01ae6e48eda	\N
1905077	\N	63	f	b79f160c-d56b-4fdc-85c2-91bdaac855f3	\N
1905077	\N	63	f	813c0506-912a-41c9-bd3d-882cb208fd69	\N
1905077	\N	63	f	e416fe2d-1d21-4e83-8753-2026b997a442	\N
1905077	\N	63	f	62e32d4e-961f-487f-ae8f-3363df794e14	\N
1905077	\N	63	f	57cc1457-a87b-4e36-ba22-fefffe6915c1	\N
1905077	\N	63	f	268c26dd-5a32-4d45-9438-e61984a44b9b	\N
1905077	\N	63	f	4121cf5d-6cee-4da2-9ce7-bf4446e8aaf1	\N
1905077	\N	63	f	bfada619-ad8f-4ea1-aefd-8de040a51c37	\N
1905077	\N	63	f	4c36ed4c-12a5-4d49-a41f-784ee1356bd6	\N
1905077	\N	63	f	4deeead3-bf7b-4e71-a967-2692e0531947	\N
1905077	\N	63	f	4b04b692-ef12-4d87-a0fc-4c0030bdb72e	\N
1905077	\N	63	f	e88b0fe4-1a81-427c-bff1-261b26cde146	\N
1905077	\N	63	f	66469a5b-b431-4b87-827e-30419c0bcbcf	\N
1905077	\N	63	f	558e9176-094d-404b-b646-b8eca9c1e510	\N
1905077	\N	63	f	64db50dc-fc83-4792-917f-4c0e363c19de	\N
1905077	\N	63	f	30ee19c0-be8a-4f3e-8024-99b8fa69ab83	\N
1905077	\N	63	f	3cdb0095-d52a-4a73-bce7-6ec56c3f51ed	\N
1905077	\N	63	f	d9c41bc4-00f9-49e8-8574-542cfac00e74	\N
1905077	\N	63	f	81c87969-237b-40ad-bdb2-2512e960c0dc	\N
1905077	\N	63	f	abb00645-aed5-4119-8b4c-5bf170251595	\N
1905077	\N	63	f	ad3cb0db-46ed-4e5b-91bd-592e072f967c	\N
1905077	\N	63	f	24118efe-f8d4-494a-84ff-f1a17afcb824	\N
1905077	\N	63	f	1fc955dd-7207-4074-ad04-29fc628e6831	\N
1905077	\N	63	f	f74e3dee-bf60-4097-8bee-480b84e0903f	\N
1905077	\N	63	f	df63b3af-8f0b-464c-8642-347cc15bf256	\N
1905077	\N	64	f	6e3638d3-6d52-407d-8d53-518a7e4b2174	\N
1905077	\N	64	f	79d2406f-65c1-4a3f-ab71-eebff5418320	\N
1905077	\N	64	f	e4fcd11a-6eb4-4599-905d-2b67c0e26ada	\N
1905077	\N	64	f	08ca11f4-2736-4158-bc3a-88f2674a01c2	\N
1905077	\N	64	f	53f801bf-5985-4500-bb13-e9fbf53fbf77	\N
1905077	\N	64	f	f0c6bc41-ac59-4b5d-b0ab-ff3646d72300	\N
1905077	\N	64	f	f596fb63-e8d2-48d6-8dfa-6b9ee2cba3e3	\N
1905077	\N	64	f	d2ceb349-5422-47de-98e2-79f4b5fe509d	\N
1905077	\N	64	f	1910a54a-cbb2-48fe-8252-f5b4ef505809	\N
1905077	\N	64	f	cb04140b-35a0-4f95-8444-81b79c5e38b8	\N
1905077	\N	64	f	a82ac942-f59d-4348-96b0-71e571b0c3e6	\N
1905084	2313	51	t	da776040-456c-45fe-965f-bbff13269576	\N
1905084	2313	51	t	52b09c9f-643c-4998-bfad-5c39908f8ec4	\N
1905077	\N	64	f	0bc74430-2d73-4247-bfd9-0ce9e675b949	\N
1905077	\N	64	f	a38bfd15-646f-4ae3-bac3-b2d80d258855	\N
1905077	\N	64	f	b6d65857-f8e1-4ba7-a357-784dc6d526b0	\N
1905077	\N	64	f	6b066baa-948c-4478-a819-a9d920a21047	\N
1905077	\N	64	f	c52e3bec-2361-47a4-b654-2101c599f0dc	\N
1905077	\N	64	f	eed86f51-95a6-4a06-b6a3-ffecbbe264ce	\N
1905077	\N	64	f	e0869636-6735-45a2-96b5-a89763ff60db	\N
1905077	\N	64	f	a33e9958-d6e2-4fcb-b80c-be1485abeea2	\N
1905077	\N	64	f	c015500a-35e8-4a3b-8608-5ad19dfb9c69	\N
1905077	\N	68	f	0bd187f2-8100-4a6e-84f5-516f60283ff5	\N
1905077	\N	68	f	e4eff7c8-c22c-4138-8767-74cfa1427fee	\N
1905077	\N	68	f	2996c072-7d00-400e-a440-7313a31b2c18	\N
1905077	\N	68	f	951391b1-98dc-4604-83e1-902907ef8f60	\N
1905077	\N	68	f	abf48fd7-be53-4c6a-b27d-514845a648f6	\N
1905077	\N	68	f	6fdf2761-4dc5-4bd7-b650-0eed2a872363	\N
1905077	\N	68	f	1ed09bb8-2fd2-4877-bffe-916a1e6209b8	\N
1905077	\N	68	f	11bda9d5-9ffb-4cae-811f-66efd0310d21	\N
1905077	\N	68	f	1ea1b936-cb83-4358-89ce-bf7a64d99383	\N
1905077	\N	68	f	8d04d388-5163-43a9-83b1-496ce2d058f3	\N
1905077	\N	68	f	81467d9b-757d-4dd7-a9e8-0f8adbe16b58	\N
1905077	\N	68	f	0bd115f5-77ef-4578-a8e0-3cd4d3d8249f	\N
1905077	\N	68	f	569d9e9c-4c9b-454d-9ad2-6893e8447b74	\N
1905077	\N	68	f	e4bfd52f-eddb-4279-aa04-21c551816b95	\N
1905077	\N	68	f	fb04b34c-2b00-4b96-9b0a-61c61f2b7fed	\N
1905077	\N	68	f	c34df162-b437-43a1-a5d8-8bc9a1c52a2a	\N
1905077	\N	68	f	dedeaac7-adcb-46b9-bef4-1c1a50c2cffc	\N
1905077	\N	68	f	d4c19704-2aa2-4087-b9f2-b983e776c558	\N
1905077	\N	68	f	1be64103-b251-4887-83c2-0fc5c011d0df	\N
1905077	\N	68	f	2088623f-63f8-4138-bde4-da5ae7e1df08	\N
1905077	\N	68	f	18d73078-16e0-4f4f-b239-ebf346f34500	\N
1905077	\N	68	f	1b9f779d-58e9-4e71-8d92-ae93fd8130ca	\N
1905077	\N	68	f	8c4831a3-5673-4c96-b3fa-5322cb36a017	\N
1905077	\N	68	f	c366921b-60d4-48d7-a146-71909f361fbd	\N
1905077	\N	68	f	067dca10-77e5-4097-98a0-337cf0e3585f	\N
1905077	\N	68	f	b2168288-b75d-49a4-b614-a8e1536f940a	\N
1905067	\N	69	f	c7d481ae-4c8f-4897-a167-3b61c1013e64	\N
1905067	\N	69	f	b883592c-d5ec-416f-b388-a3264ef0d396	\N
1905067	\N	69	f	14cbe0e0-f9e0-4620-898c-37e8247b24da	\N
1905067	\N	69	f	ebed12d5-8bca-4675-b667-f62255917e28	\N
1905067	\N	69	f	7caaff93-10ce-4cf6-8d8d-39a0cde9bf91	\N
1905067	\N	69	f	ab8976e3-9ff1-4c43-9119-1e39911aa215	\N
1905067	\N	69	f	23596021-cb77-4b42-9f54-14c4e9524d7a	\N
1905067	\N	69	f	6bedcb8c-d774-4442-bda5-dbb93148ecb2	\N
1905067	\N	69	f	3b5992bf-ea79-49d6-8422-f60c571599ea	\N
1905067	\N	69	f	08764109-bc63-42f1-9d61-e4647f4fc052	\N
1905067	\N	69	f	e1f1b465-fe3a-462f-8b5d-98656f40bdc5	\N
1905067	\N	69	f	57312e54-97ce-4fe0-a03a-9c25b99e80e4	\N
1905067	\N	69	f	f3a87356-39f8-470d-95e4-21c7f960be0f	\N
1905067	\N	69	f	012f5a6d-08fd-42e7-b82b-0089bedea5bb	\N
1905067	\N	69	f	9913ce15-ef43-42ae-b290-82a3429ca869	\N
1905067	\N	69	f	81c666c3-6933-445d-bdbe-3c484f2a5388	\N
1905067	\N	69	f	4b858a6d-27eb-4416-aa35-46746e9ed5c2	\N
1905067	\N	69	f	33912e34-32b8-4f4d-bc63-701f2acfd0d8	\N
1905067	\N	69	f	4b354b6a-92bf-4574-836c-4184dcd2788a	\N
1905067	\N	69	f	1ed7380e-fdc2-4fee-94c6-49c7f8e669ba	\N
1905067	\N	69	f	a2cfb17b-f8f9-4ad7-91ce-510ac0103c54	\N
1905067	\N	69	f	42d2a101-7d19-4ef4-a3ed-989a6429e362	\N
1905067	\N	69	f	f47a96e8-fedd-47aa-818b-65a88d271fa8	\N
1905067	\N	69	f	05ff7a43-e12f-409f-b451-de66cbe00527	\N
1905067	\N	69	f	f6577254-a227-4690-aeba-42d6b27e981e	\N
1905067	\N	69	f	35d8a04d-07b4-4788-b45f-7f8ef7e3ee2f	\N
1905067	\N	69	f	b321905d-f931-4cc7-be30-68558634e6cd	\N
1905067	\N	69	f	7b0c39a1-70de-4540-8c31-3d6d4856dc36	\N
1905067	\N	69	f	dbf09b74-16f4-4397-9ac2-6eb0a9640f5c	\N
1905067	\N	69	f	3aefe80b-73ae-4955-bead-3173dd644012	\N
1905067	\N	69	f	d054a020-f36c-4835-b6bb-4fa413685fb6	\N
1905067	\N	69	f	bebbbc95-7ad0-435a-995c-8bec98905fb2	\N
1905067	\N	69	f	5f1ed151-7ad1-4558-bc99-b3ecbc3c2ffc	\N
1905067	\N	69	f	0f04d710-ab14-467e-a664-8c5c43400466	\N
1905067	\N	69	f	41bc49c3-55e4-4e79-81bf-42145cef353d	\N
1905067	\N	69	f	108fd596-44d5-4321-b99d-a3cc8b4f0999	\N
1905067	\N	69	f	df97bb21-b8f9-4105-92b3-fd557b4f28d9	\N
1905067	\N	69	f	8786f84a-76a8-45bb-9123-efec637f8dc4	\N
1905067	\N	69	f	d49586db-f5b0-4486-88ba-8621a32c7006	\N
1905067	\N	69	f	4b6f41ab-e315-4538-8cc9-a29dab6b4c0c	\N
1905067	\N	69	f	c1ee7832-7a30-4843-8aa3-ab93d074bdf4	\N
1905067	\N	69	f	ed3306af-3968-42d5-be5f-f2b0c6c5041e	\N
1905067	\N	69	f	b71d1dfb-5f47-4737-9aa5-b84ca32eb661	\N
1905067	\N	69	f	4031b1f4-cdcf-453b-b168-2815e5b676b6	\N
1905067	\N	69	f	dd84ac45-d6a8-4aa0-828e-c70e27745539	\N
1905067	\N	69	f	e73cf18e-3b14-4f5d-ab4f-92bd56b1fa8f	\N
1905067	\N	69	f	a1186c60-7d9c-4564-afab-f4c52cbda8c4	\N
1905067	\N	69	f	4100a554-917e-4223-a8f2-b3b7bd2e27a1	\N
1905067	\N	69	f	361e4f31-0480-49d0-8b05-e93d78f3c09a	\N
1905067	\N	69	f	59d272d2-5f79-4b32-b484-3886c018a147	\N
1905084	\N	65	f	a2f21a02-f7da-4c77-a62f-d0332d3e891a	\N
1905084	\N	65	f	314e8ed9-f8de-4c03-b5c7-769ac444b381	\N
1905084	\N	65	f	f20300ea-cddb-4430-9061-0ca46ecd7af9	\N
1905084	\N	65	f	eb1895c3-ee37-4e65-a64a-267dd776a006	\N
1905084	\N	65	f	4c0f9c86-0b74-4769-86ea-9a697799407e	\N
1905084	\N	65	f	08b8e348-a724-4896-8162-924ffcfb3bea	\N
1905084	\N	65	f	24934308-342a-4608-8205-d483db8413a9	\N
1905084	\N	65	f	3b9cc5ff-1223-447c-9826-66ef41e525fc	\N
1905084	\N	65	f	176af4c7-a7e0-4eb1-8d0e-426f60f0e8d6	\N
1905084	\N	65	f	00eabb1d-06dd-4aca-a79a-b491ab4c3fbf	\N
1905084	\N	65	f	ee914d49-e94f-4f8a-8324-cfc0fcdd2933	\N
1905084	\N	65	f	f4fd8a62-2730-485b-89bc-d0df6e2560e3	\N
1905084	\N	65	f	3daa3721-63dd-462a-a396-d3df3b9f4536	\N
1905084	\N	65	f	95e31e2d-9951-406f-90d9-c97ccd8e8b5b	\N
1905084	\N	65	f	5831160c-20dc-4d36-ab0c-d5580b61f7cb	\N
1905084	\N	65	f	d19b4b98-a4e9-443a-a62a-65f4b68f4a37	\N
1905084	\N	65	f	699bf355-deeb-4cda-a3ba-17f866472fbc	\N
1905084	\N	65	f	7494a88d-80dc-4843-8582-ce67e933a485	\N
1905084	\N	65	f	49bc0fe3-f7ab-4160-b443-8f0425fb9211	\N
1905084	\N	65	f	d690b817-10e8-4e20-96bb-59f6147da5a8	\N
1905084	\N	65	f	29a5ad5e-f187-4f65-a74c-dd724bbb5a4d	\N
1905084	\N	65	f	39c8d85d-7a03-4756-b74e-6936c5f11b0b	\N
1905084	\N	65	f	4687ab46-d594-459e-bd05-c6dbb1e8a8ca	\N
1905084	\N	65	f	5f4a72fc-0371-49a7-be9b-47e15b94d285	\N
1905084	\N	65	f	14a9f86a-d7d8-4639-a3b6-5b27fcd5ddd1	\N
1905084	\N	65	f	8b05482f-08db-4acd-9374-e3d5fde0df11	\N
1905084	\N	65	f	cbfb991e-f0b8-4bd7-910d-c30fd521feb2	\N
1905084	\N	65	f	8bcb6bd4-283c-4bbf-b140-149b51c0ce88	\N
1905084	\N	65	f	6bae8285-04a5-4c6c-b796-86030d71eb34	\N
1905084	\N	65	f	e9ef9d3d-3cfd-484a-ac65-db64ad5bd058	\N
1905084	\N	65	f	a1d98beb-b41d-444a-b0d1-8c4bc446f868	\N
1905084	\N	65	f	169db0d4-6e4c-4ede-9dfc-fe3d96727252	\N
1905084	\N	65	f	a3f1a291-bb92-40e1-8894-666c38070f0d	\N
1905084	\N	65	f	1a69452b-f5b8-4d0d-b977-2eb1531ba0d2	\N
1905084	\N	65	f	6ad95ba8-c7cc-4ee8-8ac9-f83cc067c395	\N
1905084	\N	65	f	0194340c-aba5-4b2e-9b7c-7cb90c8cac70	\N
1905084	\N	65	f	60c4775f-0358-4554-947a-ddd6c8b5acd4	\N
1905084	\N	66	f	32152b8c-3124-42bc-afc5-bf5c68a22275	\N
1905084	\N	66	f	861fc405-d77d-401d-892b-0f5012c2c8ff	\N
1905084	\N	66	f	9e1419f5-0435-41a0-ba91-ac930bfa9e87	\N
1905084	\N	66	f	e37818db-da6e-4fa7-a07b-fb2f5bb41147	\N
1905084	\N	66	f	504fd066-bb63-406e-924d-ee80a8cebf3e	\N
1905084	\N	66	f	03f13a87-054d-43cd-8c32-e79591e1c34c	\N
1905084	\N	66	f	2c7131b6-0be3-426b-a862-cfcfba125ee4	\N
1905084	\N	66	f	458823fd-fd62-42d4-8368-cf84ccbca31e	\N
1905084	\N	66	f	56aafc30-84b6-4aa9-b664-999530a12f52	\N
1905084	\N	66	f	b5e11bbe-dc81-4863-ac28-af6a17f8b600	\N
1905084	\N	66	f	e0ab6988-ba5f-43e0-b875-c0142362b700	\N
1905084	\N	66	f	bec48ace-93e9-4ccf-ba87-b9719fa2e158	\N
1905084	\N	66	f	321f0f82-cb0b-494f-bf37-38168993ac7d	\N
1905084	\N	66	f	5dc327a1-5176-4700-8b6e-9ddf31e3b450	\N
1905084	\N	66	f	25f6f4d6-b2d4-4576-9096-3801306236d2	\N
1905084	\N	66	f	584eac4c-3480-4abf-9767-15cecea11c48	\N
1905084	\N	66	f	69d3435c-8977-4fa3-973d-b7aa8145c567	\N
1905084	\N	66	f	c528f2ac-c9a7-4a8b-84f3-5f972429f398	\N
1905084	\N	66	f	2cb57ff2-d168-4d65-a267-48644151756d	\N
1905084	\N	66	f	fa984ca4-6d68-4fb3-af21-6f7e8da2e2e9	\N
1905084	\N	66	f	c595b7e1-be55-42a9-9a28-3214ad0bc49d	\N
1905084	\N	66	f	88e65013-7a4f-4308-83eb-a838a69d133b	\N
1905084	\N	66	f	1086f31e-6af5-44f6-b87d-220e69948737	\N
1905084	\N	66	f	61bf59d2-b2b9-4fce-9181-f501dc4f02f6	\N
1905084	\N	66	f	6795bd5f-3626-4075-8de4-f185b4572902	\N
1905084	\N	66	f	a016d8a9-b524-4e85-a586-dfc3dd729741	\N
1905084	\N	66	f	ba5565b0-6067-493d-8d86-541c80553f9b	\N
1905084	\N	66	f	1c2317b4-82d2-4a23-8e1d-750937674ce7	\N
1905084	\N	66	f	b92e28e5-7d8a-4b57-98d5-955a896823ac	\N
1905084	\N	66	f	68243919-ab5e-4281-afa8-6d06bc192625	\N
1905084	\N	66	f	8c576009-4189-4902-bc4f-7598325cb681	\N
1905084	\N	66	f	ad11595d-cc1d-45ed-9ac0-952ff0d29708	\N
1905084	\N	66	f	2cf8a06c-0a4e-47e8-87e9-89c02a7401e3	\N
1905084	\N	66	f	24caa03a-8446-449e-9f8e-4b163b195f7e	\N
1905084	\N	66	f	e195ce19-0878-4a04-917b-b3dcf404ac95	\N
1905084	\N	66	f	5a2a4640-18b8-424a-a099-b9537c452e9f	\N
1905084	\N	66	f	17e62452-9b03-499c-b1c6-dc03068263ef	\N
1905084	\N	66	f	c10f2162-3250-4806-be84-a7c2cac06556	\N
1905084	\N	66	f	f88032aa-3767-48de-b135-587cd8a0382f	\N
1905084	\N	66	f	b3cbfa36-574d-4709-a7a8-645bafc49b71	\N
1905084	\N	66	f	16addd23-aa19-4022-a473-20ce65af68d8	\N
1905084	\N	66	f	10ab34a6-6e89-49b9-98ab-79f58737a508	\N
1905084	\N	66	f	aba25f44-ae4d-479b-9103-aeddb37123cb	\N
1905084	\N	66	f	4d30c468-f54b-4e54-8005-2632ae333652	\N
1905084	\N	66	f	47b1269f-b5ed-4a2b-97e0-beefd358b483	\N
1905084	\N	66	f	4ef68803-33a0-44cf-84b6-9a5d30f0682e	\N
1905084	\N	66	f	b8cbec12-5df0-4dc6-83f4-e1d51eb0b4f0	\N
1905084	\N	66	f	972f6beb-6e25-4c2e-96c5-99321d51bba6	\N
1905084	\N	66	f	c15edf7e-612e-4689-ae22-ce44bf0656c1	\N
1905084	\N	66	f	4fbda385-359d-49fe-aeaa-b16e262fdee1	\N
1905084	\N	66	f	1484b205-1e24-4c9c-963f-9aff18dd5cfc	\N
1905084	\N	66	f	185bb11a-86ad-454b-8a5f-95cce84ba239	\N
1905084	\N	66	f	f0c92f70-e851-4276-9c8c-9cbe839c75c8	\N
1905084	\N	66	f	1d247a3b-bd26-4d56-b7cd-ff6d5e738660	\N
1905084	\N	66	f	5e1cc760-6b27-43c0-84cd-c03b1ac9b129	\N
1905084	\N	66	f	31100532-496f-4186-b616-f3fbbdefec52	\N
1905084	\N	66	f	f5707451-d3c6-4f1d-88d5-b265ce44793d	\N
1905084	\N	66	f	f5f9c00b-4170-4943-8219-c0d0f3ab4eae	\N
1905084	\N	66	f	fe6eb20a-23f1-45d2-9aa5-b592d747c9b1	\N
1905084	\N	66	f	c1a98ad4-b45d-4ada-be52-cd7355a6e8e6	\N
1905084	\N	66	f	fa35ace9-8239-45fd-8120-6516e5da7eb4	\N
1905084	\N	66	f	52458fd0-2ed7-4087-b954-28f4e5ea1dfc	\N
1905084	\N	66	f	1c9c8b14-b5c5-4518-a16c-a2fb909d358e	\N
1905084	\N	66	f	7388e93f-b583-47e9-8a3d-726a631ea958	\N
1905084	\N	66	f	c5499de7-206e-473a-be40-9030fc09b151	\N
1905084	\N	66	f	bf3220a6-d39e-4e4e-bbe6-84bcbfa5b4ec	\N
1905084	\N	66	f	cd9a6f70-7748-43a2-8f51-5e0578943564	\N
1905084	\N	66	f	068c4147-0873-48be-8fd0-1024cffafc6c	\N
1905084	\N	66	f	ab1b68c3-fd2d-4e1f-9164-f1ca72abea2a	\N
1905084	\N	66	f	76334732-94ca-47f5-ae6c-61cc9e470950	\N
1905084	\N	66	f	8c8d0403-8dd2-440d-9d66-58848331e0dd	\N
1905084	\N	66	f	4fac10da-bc19-4d73-946c-cc2fff4cec81	\N
1905084	\N	66	f	d3b4db83-2969-4eb0-b039-bd8360fb356e	\N
1905084	\N	66	f	c430a46f-9ee0-4ce9-80b8-e18b56f612b7	\N
1905084	\N	66	f	a26071d4-1fab-42ea-801a-50f86de086d0	\N
1905084	\N	66	f	cc6e93ad-debd-4960-8ace-9312653f2894	\N
1905084	\N	66	f	21cb8e91-ecd4-4f24-95c6-8d750fb71da0	\N
1905084	\N	66	f	c6b77d42-28fc-4507-8818-9c56c734df00	\N
1905084	\N	66	f	1d85f76a-aa4d-43fd-8810-3f0ab7cfa2d0	\N
1905084	\N	66	f	1465c027-5923-427f-a751-361dc6d9691b	\N
1905084	\N	66	f	346e05a1-2fdd-468b-b791-9e056406261c	\N
1905084	\N	66	f	5e9472ad-20d8-41dc-98ac-7ca0c87cbe79	\N
1905084	\N	66	f	859cd4b5-90a1-4ae9-9e88-cd42d6117657	\N
1905084	\N	66	f	da3c0028-8c67-4751-8fa4-3268333f675b	\N
1905084	\N	66	f	38d98b57-0b34-4c83-aa84-debbe0d3cee8	\N
1905084	\N	66	f	e4a6f334-3524-490b-a7b0-03942cfdb26d	\N
1905084	\N	66	f	210b85bf-0002-4e99-9a1e-06d27f1acba5	\N
1905084	\N	66	f	6d38d175-0741-4d90-ae81-8d5b2e7533f6	\N
1905084	\N	66	f	00f79023-39b9-4e1a-9117-93e5ecfb5df2	\N
1905084	\N	66	f	ac928be9-84f7-46df-a9fb-4b8a31cd4c40	\N
1905084	\N	66	f	c7111caa-a5c4-4993-9d0a-7cc60908cdb9	\N
1905084	\N	66	f	c64e3cdd-6b8d-4567-beda-71d4d2cb3dc4	\N
1905084	\N	66	f	81db264a-735e-4c42-8828-e3f1857d074b	\N
1905084	\N	66	f	23a9a7e2-fcc1-42e0-b5bc-19b76c586641	\N
1905084	\N	66	f	19f80566-add7-416b-b592-ff4dac54b5d2	\N
1905084	\N	66	f	eac40f44-7239-4863-86fb-1d7077021a15	\N
1905084	\N	66	f	c80ffb47-82eb-479f-9e1e-ac0afc61c477	\N
1905084	\N	66	f	57527e93-7ad4-4c80-aa14-7c6e139b6847	\N
1905084	\N	66	f	5e3891bc-dec7-4353-9fa2-2450abd5b72c	\N
1905084	\N	66	f	6ab9ae3b-cfe9-46c4-b1ee-88893140b21d	\N
1905084	\N	66	f	b27a9ef9-c610-4d2a-8f0c-7ea2f011f021	\N
1905084	\N	66	f	869864ce-1986-4675-bd5e-d330b0d98919	\N
1905084	\N	66	f	84ae895c-b7fd-4544-b238-42d3e1bb0c5b	\N
1905084	\N	66	f	05c763ee-8bf4-46f0-8366-fd12bbfb700f	\N
1905084	\N	66	f	f01a410c-41b3-4cdc-b04e-a9a7e200065b	\N
1905084	\N	66	f	63ce46d5-5919-418a-b253-8e3bf921b309	\N
1905084	\N	66	f	d0684f62-b674-4e3e-8c5a-bda695f6d2cf	\N
1905084	\N	66	f	b729a7d7-d803-4acd-9810-1a38365fbdb8	\N
1905084	\N	66	f	c7d11f8d-01e4-47b3-a0ed-d7860ea81815	\N
1905084	\N	66	f	096499be-e3cf-4c15-9b79-eef14be8474f	\N
1905084	\N	66	f	9c842103-0e02-479b-8024-d3e94d709494	\N
1905084	\N	66	f	a3656b78-a53b-47d1-8e95-1dc65c57167e	\N
1905084	\N	66	f	b4f8cac7-fa60-4e52-8710-e81f59399aaf	\N
1905084	\N	66	f	84c063ce-4c0a-4b16-b21d-758e41662f35	\N
1905084	\N	66	f	d0dca5ee-d2d7-4ada-bad2-3c5495217c79	\N
1905084	\N	66	f	29ec1a56-4aba-4a25-aa36-469fe4eee1f0	\N
1905084	\N	66	f	6c8d5fee-683d-437d-80e7-49e83ea9e50a	\N
1905084	\N	66	f	bb45b70b-1bb1-4431-b54e-4ac3df99c6e3	\N
1905084	\N	66	f	27773324-3464-4b7b-8cf1-54f8a2cfa78f	\N
1905084	\N	66	f	c94a9fe5-3656-4b47-89a4-fa99b3923173	\N
1905084	\N	66	f	9e9e264a-42d3-47eb-9168-3714ff5b1fbb	\N
1905084	\N	66	f	cb67ab1a-a9ba-4269-8ca5-0fd640bef3ea	\N
1905084	\N	66	f	0c44504b-23b1-41b3-b796-d3b3376d90dc	\N
1905084	\N	66	f	037bade8-0fcd-4367-8409-8e1625609ff2	\N
1905084	\N	66	f	a3c44988-4e8d-4749-8f7b-fb8579b10642	\N
1905084	\N	66	f	c430b2b5-4676-4c76-8f53-07bfb6bd95e0	\N
1905084	\N	66	f	8cd7c706-9fe4-4ed3-841b-0184a2016053	\N
1905084	\N	66	f	4f084323-8e0c-45f2-840c-fa1f68c0fb96	\N
1905084	\N	66	f	fb1311e2-db3e-4b31-8589-2e5585d5c769	\N
1905084	\N	66	f	d703ec0e-a088-49bc-a65f-8fede43ee860	\N
1905084	\N	66	f	e65a7f70-b420-4271-86b2-e10e7eb7dc92	\N
1905084	\N	66	f	d460c62d-23eb-4251-8889-07501f6cc232	\N
1905084	\N	66	f	8b2dfcc3-a0ec-4849-8e18-978d4d66dcd1	\N
1905084	\N	66	f	f1ca0cfa-6229-490b-b760-f3df2fdb55a7	\N
1905084	\N	66	f	de1ba0eb-be4b-42ac-b165-308a1a3778c1	\N
1905084	\N	66	f	cfd530a6-91aa-4f79-8b19-000715466559	\N
1905084	\N	66	f	64dc2ece-fe98-4c91-8ec4-f77122768278	\N
1905084	\N	66	f	b6d8cb3b-35f8-440a-b9b9-27bdf0923c41	\N
1905084	\N	66	f	696d1219-1314-4b01-b0e9-d865bb4761f0	\N
1905084	\N	66	f	2e2da718-8016-4d11-bcdb-181988e598a6	\N
1905084	\N	66	f	2d76d5da-e7dd-4f69-a742-7b7ac025ad33	\N
1905084	\N	66	f	d423bd5f-5897-4a56-ae39-05c20b30e185	\N
1905084	\N	66	f	f6843034-4bed-438f-8956-84a16607e6d8	\N
1905084	\N	66	f	bf830f71-c977-45f7-9c9a-2ed0a89785fc	\N
1905084	\N	66	f	07b60d59-5f4f-4081-a33a-c0b8c968dcec	\N
1905084	\N	66	f	8ed39583-0f0a-48b5-a217-16c4477ee93f	\N
1905084	\N	66	f	0d863773-82bc-4580-820d-4bde37ffe2d6	\N
1905084	\N	66	f	2b64c57c-5f42-4a09-9616-530a2451d49b	\N
1905084	\N	66	f	73cd8c20-34e8-4cab-8938-eb76a23c8c7c	\N
1905084	\N	66	f	8263aeee-5902-4982-961b-193ad3aad766	\N
1905084	\N	66	f	8ab8e813-1dac-43e5-91b2-9c7acea7f5c3	\N
1905084	\N	66	f	9c943c3a-c66a-4502-9038-cb39a11ee221	\N
1905084	\N	66	f	cd9142a1-ca15-4474-be01-5271fd262946	\N
1905084	\N	66	f	c35c92b3-5766-4e97-8366-f398e383339b	\N
1905084	\N	66	f	d64193bb-cb1b-487f-8c75-2860ac2a3361	\N
1905084	\N	66	f	5cb1dfd9-425c-4341-8726-5200cbdfa4af	\N
1905084	\N	66	f	3bf9f7bc-7b98-454b-be3a-7cb88e2226b2	\N
1905084	\N	66	f	7810c872-a189-4dc0-9dcf-fb526aeb2c88	\N
1905084	\N	66	f	b43d7e57-88e7-4a1d-a462-5cd1f78312d3	\N
1905084	\N	66	f	8a00e255-bfc6-4dbc-a48d-c34ad570c24e	\N
1905084	\N	66	f	188bb326-594f-42a4-9f27-3d92d2d0415e	\N
1905084	\N	66	f	e6ecfa10-313f-4658-9ca2-86f7115af001	\N
1905084	\N	66	f	ec4c47d3-7464-4ffb-b892-85ef3b98632c	\N
1905084	\N	66	f	3e52ea7e-3e8b-44ce-aee7-8d863f724b85	\N
1905084	\N	66	f	7b50bdc6-31c9-4ba7-b1a0-87b1d75076f2	\N
1905084	\N	66	f	be3789a0-9abd-405c-84d3-c30a0168e26c	\N
1905084	\N	66	f	e6faf3b5-b075-4317-b853-7e7adc267837	\N
1905084	\N	66	f	62c16d56-fe4e-4010-926f-6b849359c562	\N
1905084	\N	66	f	90fa4716-7fcb-48a5-85be-45f673bb0d81	\N
1905084	\N	66	f	f77834f0-c4d4-4204-b18e-67ac2c87a10a	\N
1905084	\N	66	f	7bcc9e03-7f09-4c69-a50e-91bd71fbaaef	\N
1905084	\N	66	f	126f4236-84f8-46b5-ba23-1d3f9a7e680c	\N
1905084	\N	66	f	75fcadc8-a51a-4b35-afde-c23abc6ac1e8	\N
1905084	\N	66	f	7fa81820-9763-405e-a11d-e1fed293201e	\N
1905084	\N	66	f	97dba235-b37d-458a-b08f-4c7fbbb4b238	\N
1905084	\N	66	f	ec747836-d424-4196-a9f2-93cb3f4954c9	\N
1905084	\N	66	f	4776c6ce-e3d5-4a67-9ca4-72133a41b707	\N
1905084	\N	66	f	dfc865ab-6113-440e-9fc7-a350a7688983	\N
1905084	\N	66	f	cc54c6ca-f1e0-49ba-859d-d0caf58c7ebc	\N
1905084	\N	66	f	4fe330e4-f30e-4423-9211-50ce96b896fd	\N
1905084	\N	66	f	679cb881-eb34-46a0-af1b-c03ddd299783	\N
1905084	\N	66	f	80f821cf-f99f-4974-9692-e1688ccaa70d	\N
1905084	\N	66	f	c3e5c596-0da8-4c37-970c-cd37b905b3ba	\N
1905084	\N	66	f	13eb95a8-643a-48b1-8c4d-c94dc5bf98d1	\N
1905084	\N	66	f	0aff5b7e-d032-487c-a634-e094627e06f1	\N
1905084	\N	66	f	402133cd-4f7e-476e-9db1-d5cc853a4268	\N
1905084	\N	66	f	bc332a69-6557-43f7-bc10-ac31b0a9b99d	\N
1905084	\N	66	f	821bc087-f857-4fea-8e83-42273b4b7898	\N
1905084	\N	66	f	6eb963bb-45ca-45da-9463-5120023a4c71	\N
1905084	\N	66	f	7419f582-f7c4-484d-ad7e-75a715738d26	\N
1905084	\N	66	f	5b0d99b0-eb96-477b-97ec-85ee19f9fd81	\N
1905084	\N	66	f	301af11c-553e-44fa-8a0f-88a29013ebb1	\N
1905084	\N	66	f	ef8482a6-3b09-4357-b05e-2f465763ea1f	\N
1905084	\N	66	f	c5380ec2-b7c6-446d-847b-5b4279f61d92	\N
1905084	\N	66	f	a062c8d1-2da6-4ba2-8ea2-ee09253ad583	\N
1905084	\N	66	f	0fed4a4d-cfba-42ca-9088-6a85cd5f44f1	\N
1905084	\N	66	f	cc3dc31b-a7a2-4cf9-8821-08f979f8a1dd	\N
1905084	\N	66	f	2774e78f-c1e3-40c5-a5ce-04edef490492	\N
1905084	\N	66	f	d29d20af-e978-46ba-bb38-a61092f81ad5	\N
1905084	\N	66	f	67c865c2-10ad-4078-904a-c892300d9c9c	\N
1905084	\N	66	f	485109bb-b262-477c-8c09-96332cee8172	\N
1905084	\N	66	f	0ae3e995-96bb-44d9-99f4-3421e4a6b0cd	\N
1905084	\N	66	f	e44018b8-f9e5-44f2-9b53-9b459938e149	\N
1905084	\N	66	f	3f143230-0c46-4d54-bc5d-0dd620644f84	\N
1905084	\N	66	f	ca36672d-a65d-4955-836e-377f218d3c4d	\N
1905084	\N	66	f	21bed1da-21f9-4abf-8d2e-b88fb7e76537	\N
1905084	\N	66	f	3cd14f3c-4785-4cd6-ab22-e3b1a9d1f3d0	\N
1905084	\N	66	f	464600a8-34e0-4b7f-8840-de0403f8f6b9	\N
1905084	\N	66	f	0fe01e23-214a-4113-bc4a-66868952d3bf	\N
1905084	\N	66	f	b180b559-e6db-4822-8f48-e37e59a627fa	\N
1905084	\N	66	f	425f60ec-e123-4b0f-b0e5-db69403348fe	\N
1905084	\N	66	f	c697868b-433f-4108-b19d-7758aec89bac	\N
1905084	\N	66	f	d7458d7e-956c-41a7-a10f-a04b8e21a405	\N
1905084	\N	66	f	39f00816-3360-4142-b0c7-57d863339949	\N
1905084	\N	66	f	b558d482-f53e-4a6d-9a77-9ace6ba0e6a3	\N
1905084	\N	66	f	9097824b-d052-4750-8831-f1c6c9fde8c2	\N
1905084	\N	66	f	f17f20d6-12e0-4cb5-b7d3-2a936e772ffa	\N
1905084	\N	66	f	895d740a-f4b7-4abb-87c2-93730719aaf5	\N
1905084	\N	66	f	30925999-ee6d-414a-bab2-cbd58f0ecf87	\N
1905084	\N	66	f	1f13e0ef-fbc5-4342-80c5-2eabc3e854d1	\N
1905084	\N	66	f	ece136dd-558d-4efb-a912-2c31f28c6cbb	\N
1905084	\N	66	f	982adb85-bc5d-47b4-baaa-175cea34db07	\N
1905084	\N	66	f	b19c2f62-8a85-4939-b593-3834f11f7e31	\N
1905084	\N	66	f	6782378e-df96-4372-b2ad-cf9110628ded	\N
1905084	\N	66	f	747562aa-bdbf-4e5d-bdb4-09d6d7e6983d	\N
1905084	\N	66	f	4be32c4c-8e04-49ee-9c35-d3277c0e2535	\N
1905084	\N	66	f	caa5f487-6df1-4dd7-acba-7c4a183aa2db	\N
1905084	\N	66	f	29f8097c-f88b-4ab0-8d5f-a8eb9a5f9448	\N
1905084	\N	66	f	0ec869b2-4b65-48b8-8ac2-2ad94c9b1009	\N
1905084	\N	66	f	a5faf746-dd89-4705-a91c-56a6a4f0cd2b	\N
1905084	\N	66	f	03f2c5d0-f18a-477f-8310-f1ac1982ebf5	\N
1905084	\N	66	f	037d293b-41a7-4be3-bd42-b85175372f33	\N
1905084	\N	66	f	dc216267-f30d-43ae-999b-534779911ee9	\N
1905084	\N	66	f	c5c6f951-e2ef-4d94-ab5f-2277ee9ae211	\N
1905084	\N	66	f	3656d56e-7956-470a-a808-02975802336c	\N
1905084	\N	66	f	7467c0ae-43d0-4b00-8080-1c4799136d2b	\N
1905084	\N	66	f	62a20062-0915-4f35-8994-aaa24279d79b	\N
1905084	\N	66	f	c7ee4a20-cce5-4255-a828-baec5edfa26b	\N
1905084	\N	66	f	8749a323-c111-4395-9af1-b960dd273d31	\N
1905084	\N	66	f	bf9bcbf0-b061-4b26-88eb-5f1ad4b4f009	\N
1905084	\N	66	f	aa31e167-4e75-4297-bc9a-1f2d1a55b82c	\N
1905084	\N	66	f	7f8a0fd8-a2e0-41c8-885f-1aa6ab8de4b7	\N
1905084	\N	66	f	2d10d269-bce6-4eab-ae6d-60e5e2d62a2d	\N
1905084	\N	66	f	c57fb035-7aff-4065-ac69-f7175afea305	\N
1905084	\N	66	f	b7470fdc-89e6-4a01-a96a-19bf0cc7c0ad	\N
1905084	\N	66	f	87adc31e-a137-4f50-aff5-5f9e810db509	\N
1905084	\N	66	f	fa92d0af-2d20-4070-bb69-b2a3dd8ea19a	\N
1905084	\N	66	f	cf5c02a3-e955-4e67-86cf-f4d24b70afa0	\N
1905084	\N	66	f	9c76aebe-5ee3-4f71-b758-68ae73935a34	\N
1905084	\N	66	f	4677615a-d346-450b-a444-fab0bafff7a3	\N
1905084	\N	66	f	104d6f6e-1758-4c15-b899-23e30939ebfa	\N
1905084	\N	66	f	e2230efc-b72d-47c9-8d69-0e54bea243a3	\N
1905084	\N	66	f	6b3dc777-2dcf-4020-8f1e-2c870ed41f02	\N
1905084	\N	66	f	cd413022-7a56-4bc4-8950-4772dbc70707	\N
1905084	\N	66	f	691032dd-9088-4827-974d-73364ff23996	\N
1905084	\N	66	f	7675997b-b911-4358-9330-ba0ca74f34fa	\N
1905084	\N	66	f	aad2b9e3-9c21-44d3-9592-b6962e6331de	\N
1905084	\N	66	f	27ad00a7-394d-45f6-8773-38d8c3557fa6	\N
1905084	\N	66	f	18fe5994-275f-4a20-a00f-688ec0dae50f	\N
1905084	\N	66	f	961bed4d-ce5a-4755-be63-ae5a25c9ecb8	\N
1905084	\N	66	f	bd1f1b2c-240a-48be-bfae-acea696971e9	\N
1905084	\N	66	f	b44bb079-5449-4801-8178-7e172b9e972d	\N
1905084	\N	66	f	9e899410-4abc-4c9f-a1b9-5ce63f638baa	\N
1905084	\N	66	f	1223b309-8d71-4112-a5f4-bfd19f2a0bbb	\N
1905084	\N	66	f	21932e40-563b-4643-b321-654841b184d8	\N
1905084	\N	66	f	a4086425-2339-454e-86d0-6fc724927e4b	\N
1905084	\N	66	f	18825be2-a5c3-4608-bbf8-6ee17e22bb31	\N
1905084	\N	66	f	0412a182-c876-418a-948c-ea74ca825c37	\N
1905084	\N	66	f	3cf10b05-e58b-4731-95cc-8ea2d23a5d74	\N
1905084	\N	66	f	923257ea-5e03-4c4c-b993-3a50a5f44b6f	\N
1905084	\N	66	f	9d26c701-37c8-4f9b-83b4-0d65efac5936	\N
1905084	\N	66	f	4e6ac532-fff7-4a2a-baec-5bd0f458e317	\N
1905084	\N	66	f	2c6be705-261c-43b9-ae47-1821849db9a9	\N
1905084	\N	66	f	cdeab404-0809-43e9-9a86-80b205f98abf	\N
1905084	\N	66	f	cb1f4847-5f6f-418f-827a-b45b1a5ce504	\N
1905084	\N	66	f	a276f3ed-2684-4bf0-86ae-13c2f8aad02b	\N
1905084	\N	66	f	d2cd3b0b-32b0-4f59-bd03-0b6302fdb8ea	\N
1905084	\N	66	f	86a6ef34-f705-4988-ae26-64b67bdd988c	\N
1905084	\N	66	f	cacc9749-0232-47cc-a4e4-8607ae3c676c	\N
1905084	\N	66	f	d6056849-d08b-4191-82af-79352b0249b0	\N
1905084	\N	66	f	b7365b72-e5c0-49b7-a3fc-67567934c3ba	\N
1905084	\N	66	f	136a6727-4fc1-480d-9e77-f31aa8fdde4c	\N
1905084	\N	66	f	0b14a642-db04-49e7-8cbb-f933fd8aa18f	\N
1905084	\N	66	f	58ef65cf-1c9c-4d2b-b321-2123289b70f0	\N
1905084	\N	66	f	8cdc3e8f-8238-4fe7-a2fc-d4a43e843f30	\N
1905084	\N	66	f	d110b7f0-f335-4e56-92a3-863e092dcb6d	\N
1905084	\N	66	f	c2bcae34-32d0-4cce-b05e-44d29aa8cefd	\N
1905084	\N	66	f	ec55dbd8-042b-4925-a5ea-8ca826fbe347	\N
1905084	\N	66	f	c02c3d9c-cd7b-44a6-b21f-c7509c591f7e	\N
1905084	\N	66	f	b972f61b-c842-4bac-8118-07524ecc2d57	\N
1905084	\N	66	f	402042e6-b5cd-4e26-9638-ce78ad92a61a	\N
1905084	\N	66	f	43cf6a78-409f-46e8-ab86-0dfb2aac596f	\N
1905084	\N	66	f	784b67da-2a3c-4536-a044-757b665e4648	\N
1905084	\N	66	f	e077b175-560c-4f18-85b5-dc5e8ed6943b	\N
1905084	\N	66	f	a4e16041-7fcd-46bb-bff8-9e5deb31f1f2	\N
1905084	\N	66	f	4b161b99-807b-46f5-b312-7f4a7a864443	\N
1905084	\N	66	f	d62ec059-4590-45f7-a26f-71345fc1f260	\N
1905084	\N	66	f	7e6fb724-7e0e-4b37-a9ed-9ffaf20280dd	\N
1905084	\N	66	f	6582325f-e715-40eb-bb5b-6430854873d7	\N
1905084	\N	66	f	2bf48557-02d2-4eb7-aa87-9e5fafa3093f	\N
1905084	\N	66	f	a28532db-de7b-43e3-a892-77a3cc6b8140	\N
1905084	\N	66	f	64e569d5-e85d-4aa2-a8ae-320facfd1dbe	\N
1905084	\N	66	f	f49c5ed0-5e0a-4578-8c46-397725bd4cd8	\N
1905084	\N	66	f	7a379d7f-dc9a-483a-bc22-8b398e3264d0	\N
1905084	\N	66	f	e7931cf0-5768-4751-b7e3-9009db0e6e64	\N
1905084	\N	66	f	afbc5e67-9ad7-4c6f-8a45-1a5f178d3ac9	\N
1905084	\N	66	f	41291fa5-506a-4fe5-8151-27380856b65f	\N
1905084	\N	66	f	31daa037-ce8b-4934-8d08-407ba7754613	\N
1905084	\N	66	f	6ae179e4-c774-4d1d-9b20-bdd7e15df819	\N
1905084	\N	66	f	f18c2d96-61de-4952-a167-9e1cb1945e92	\N
1905084	\N	66	f	109d4fb0-529a-4fd7-b5fd-789abdd76a69	\N
1905084	\N	66	f	ecc66c2f-14c8-4016-b7e4-2255dcbad40a	\N
1905084	\N	66	f	57e9c058-b379-49b6-8bbf-7140b0eaee8b	\N
1905084	\N	66	f	c4589698-0d07-4d8e-8580-bdd873fc38ec	\N
1905084	\N	66	f	426160b4-9fea-4988-aa1d-bead7ec0a640	\N
1905084	\N	66	f	dfeda129-3913-40b6-b326-22c64d5bb019	\N
1905084	\N	66	f	d8208c01-496f-4774-8827-eddc56d3b87f	\N
1905084	\N	66	f	ad15f12e-6903-4095-85c9-01719dd674fc	\N
1905084	\N	66	f	5d86ca1a-fc07-4f0d-8210-7c02bb742ed6	\N
1905084	\N	66	f	104d2a89-7ab8-4f59-8cbf-a5a0a49fc6c3	\N
1905084	\N	66	f	7ba6740a-eb81-4e42-a4ad-e2d518c963cd	\N
1905084	\N	66	f	5bd56012-3e0a-411e-aa15-d2862dbf7ef6	\N
1905084	\N	66	f	db1cc957-90f0-4fed-843a-7d6705257c61	\N
1905084	\N	66	f	6f8aaae9-395e-4da3-a5d1-01323d6d0369	\N
1905084	\N	66	f	0e257ca9-9d0f-46f2-b1e1-8e49f7f60bd9	\N
1905084	\N	66	f	6f162dbc-3e0c-4acd-99d7-56eefbd28db7	\N
1905084	\N	66	f	69ede00e-b406-40a5-8a77-a31a281c694e	\N
1905084	\N	66	f	cdd8cb3d-ab07-43e4-bdaa-8fd3be3970f7	\N
1905084	\N	66	f	212f5e0c-b2a5-493b-b418-6b64c4cdf904	\N
1905084	\N	66	f	6c92c776-b292-47a1-b396-302b994e4afb	\N
1905084	\N	66	f	b0ca30e9-66e1-478a-b758-75dd6530c3df	\N
1905084	\N	66	f	64454bb8-9866-4ce0-a2be-47e79fd53ab5	\N
1905084	\N	66	f	121f2906-84c9-4ccf-8adc-a4d364b81377	\N
1905084	\N	66	f	70346dc3-36db-4d01-b3fa-016353a0e6b2	\N
1905084	\N	66	f	515ff659-b49d-4241-83a0-a4f4d76ccf62	\N
1905084	\N	66	f	57458fb8-09be-40c2-bcc3-fbfecea65775	\N
1905084	\N	66	f	3e42ad4b-17d9-4ffc-92f3-8f24bf58f481	\N
1905084	\N	66	f	c3df2962-2a22-4307-99c5-ed3fb5ff512b	\N
1905084	\N	66	f	16d140d6-ad8c-498c-b125-1ea53da83782	\N
1905084	\N	66	f	85d5f961-62d3-4d5f-86ea-698eae3699dd	\N
1905084	\N	66	f	ffb74d2a-4fc4-4887-8d3c-90207b79a0f8	\N
1905084	\N	66	f	ff4f57d7-d321-42c4-9f7d-4227c052eb13	\N
1905084	\N	66	f	0a397897-b1cc-4030-b422-a09ccdf0883b	\N
1905084	\N	66	f	9ef836c9-77a6-41c7-8c31-c6d79f671964	\N
1905084	\N	66	f	081f83b9-36d3-4f1f-ba80-b084be4024b9	\N
1905084	\N	66	f	400f0782-d17b-4db8-9a58-477b6984b0a1	\N
1905084	\N	66	f	57ec7ed7-894b-4090-9feb-78ff1b2efa13	\N
1905084	\N	66	f	4a67894a-da88-4709-a9b0-a85543815b22	\N
1905084	\N	66	f	687c1b18-2060-45c5-aa25-b902809bf767	\N
1905084	\N	66	f	cf82ef2b-d226-4ead-b100-6b61a519cad4	\N
1905084	\N	66	f	b9b4c570-ae05-40eb-a0fc-1f3913cd3872	\N
1905084	\N	66	f	4f14bafa-3f91-4499-8639-6004fe02d534	\N
1905084	\N	66	f	78e59bd2-13e0-4b55-b283-0e4457330ecd	\N
1905084	\N	66	f	34c6be94-79e1-46e5-98e9-13596ee29062	\N
1905084	\N	66	f	58861895-0424-4047-a9e0-aeb737cc80ff	\N
1905084	\N	66	f	1cf61d78-6d08-4866-8cc9-6ee63f729b3c	\N
1905084	\N	66	f	22ff94b8-2600-45fe-a662-a88a294cddd6	\N
1905084	\N	66	f	24a91d8c-5590-4aeb-af8d-44733a313546	\N
1905084	\N	66	f	a9a4c733-1048-4029-83f5-eff25f940fbf	\N
1905084	\N	66	f	b3145d77-d3bd-473f-aeb2-2621cdaa70da	\N
1905084	\N	66	f	dc49fc69-861b-400c-9328-daf2dbf77e33	\N
1905084	\N	66	f	ef018b9b-9111-4581-8e69-6f9ac94afdb6	\N
1905084	\N	66	f	9e94dfa4-685a-44ec-a171-b0a1a2967844	\N
1905084	\N	66	f	7433272d-0343-4a3a-9dcc-332bdfbc1813	\N
1905084	\N	66	f	bd1dba14-cda0-4c8e-9fe7-d8f2b2705b9d	\N
1905084	\N	66	f	040b20a9-4dda-41fa-af8b-f2123fe770c4	\N
1905084	\N	66	f	1915cfc8-7676-4d1e-bf4c-c668d036001b	\N
1905084	\N	66	f	9ac725b7-31a5-4386-b626-95765181f702	\N
1905084	\N	66	f	ac273e70-3620-42a6-9dcc-4c9bab8f6c56	\N
1905084	\N	66	f	d6625ac4-c29f-4a34-99eb-807a462c3b5a	\N
1905084	\N	66	f	1a9fecb1-c983-4975-97dd-cb8b852636da	\N
1905084	\N	66	f	344fcbcf-695f-4023-ad04-e6545ab1a39a	\N
1905084	\N	66	f	55d1ca9c-1ddc-4d85-bf0d-28613edd85aa	\N
1905084	\N	66	f	790b4d33-b188-4d1f-bdf5-a70909ca90da	\N
1905084	\N	66	f	fd3471bf-526a-4283-a2b6-8784acad041e	\N
1905084	\N	66	f	9110f74b-b663-4a78-93e3-48c7ce501be9	\N
1905084	\N	66	f	a7b87e2f-c3c7-4a72-8de8-c210b102674e	\N
1905084	\N	66	f	756203f3-4fc1-4b81-b8ee-d012f14c15c7	\N
1905084	\N	66	f	b52c84c2-4d1b-47f3-97b9-c6e81b843254	\N
1905084	\N	66	f	a0fb05c9-ec00-40c4-ba60-7a756b2971cb	\N
1905084	\N	66	f	25c93b71-e587-47fa-8f9f-12a85332f15a	\N
1905084	\N	66	f	9271e480-e5fc-4122-acf4-c8cbba17c430	\N
1905084	\N	66	f	b7bbc0f4-3595-47af-ae3f-39980409eee7	\N
1905084	\N	66	f	d94c69da-c584-4c60-b659-fd22e1737f5e	\N
1905084	\N	66	f	8dd1cfeb-ca1b-46cd-b452-5dfddb84bae1	\N
1905084	\N	66	f	c4d44272-46b0-414f-b4e3-2a25550a60f0	\N
1905084	\N	66	f	ade60336-040c-4dda-9e67-af404c7b8ca1	\N
1905084	\N	66	f	be97bb7f-dda7-4db0-8029-468e8605a579	\N
1905084	\N	66	f	dd3d05b9-3696-40e7-b433-3e4fb839902e	\N
1905084	\N	66	f	e7af09f6-68ab-4f21-979c-0ff9327ba7e8	\N
1905084	\N	66	f	0db691fb-ff69-4c1a-bf52-1b0b9ebb94cd	\N
1905084	\N	66	f	0a74493a-abdc-45fc-9a8e-aa9eb9cf70de	\N
1905084	\N	66	f	ecbaf60a-91c8-4a8b-8ee3-930b8d202308	\N
1905084	\N	66	f	20a93e28-2a44-4ccd-8ff9-cee931b5c361	\N
1905084	\N	66	f	e8b71d6c-a03b-48c5-8754-5dd752b43e0d	\N
1905084	\N	66	f	9d23c6a5-7d2b-4a8d-9ccf-3e006f2bfef1	\N
1905084	\N	66	f	cc516204-cb2d-46ec-9e65-6d21923dc84e	\N
1905084	\N	66	f	ad690483-90b3-47bc-8c59-41cdfde9c658	\N
1905084	\N	66	f	5ec0c131-bea7-45dd-b725-cc2be710eb79	\N
1905084	\N	66	f	4e746482-fd3f-4d41-8814-ed700612bc1d	\N
1905084	\N	66	f	66d00f41-5b73-4dc5-8500-035b9c0ebd9a	\N
1905084	\N	66	f	90e0ca6d-37bd-4923-bfe9-bd1a248ba827	\N
1905084	\N	66	f	295ef0fc-e728-4f09-ad38-3f1bd5541c6b	\N
1905084	\N	66	f	b9cc255a-c520-42c4-aa43-a3e416138fb1	\N
1905084	\N	66	f	9e02babb-2356-42ec-b8b2-7c9add69f64d	\N
1905084	\N	66	f	f9483c93-effe-492b-b1bb-ece81c52f47b	\N
1905084	\N	66	f	739cfb31-c06c-476d-ade6-861b9044e253	\N
1905084	\N	66	f	959d13cd-6770-4481-9e5a-7bb0c7f8e8d8	\N
1905084	\N	66	f	865e3a98-b5a8-43a8-b8ee-0f72b20f1edf	\N
1905084	\N	66	f	792322d8-cc3c-4052-a253-5a7eb54af7f5	\N
1905084	\N	66	f	753c6fea-1939-4791-b44f-e50508757714	\N
1905084	\N	66	f	839e04ec-337b-4a98-960d-d45a9d01a466	\N
1905084	\N	66	f	16800e66-a675-4de3-84bb-0189ee497935	\N
1905084	\N	66	f	8d3428d7-881e-4d43-a0de-0b927e955247	\N
1905084	\N	66	f	74acdee1-09be-4cda-b1e8-fe666ee6db32	\N
1905084	\N	66	f	1d842864-78b1-42af-9de2-a01897257d17	\N
1905084	\N	66	f	9ae6d8ef-aa45-4122-b056-86b072ea6734	\N
1905084	\N	66	f	416a66cf-4951-4876-8d9c-6e7047c8d857	\N
1905084	\N	66	f	bef980c4-75ab-4c64-a199-ac9f51519c2c	\N
1905084	\N	66	f	ce3d3cb9-0815-4d91-974a-a7a2bce9d080	\N
1905084	\N	66	f	ecfdd37e-6ca3-4dfe-b852-ab72fb3d647c	\N
1905084	\N	66	f	5d0f7457-abfb-4568-a2e8-cbe24cacb31e	\N
1905084	\N	66	f	082fc974-4775-4a39-867a-f4895f70f10a	\N
1905084	\N	66	f	90cd6a20-6c08-40fe-8e75-a5ced497aaa9	\N
1905084	\N	66	f	a4f8b709-48e7-457f-b0bf-6a89c7b4c422	\N
1905084	\N	66	f	4e5b270e-0cfb-4437-a416-349885be88fa	\N
1905084	\N	66	f	21374080-9da5-4522-addd-f6d72a37003c	\N
1905084	\N	66	f	ec5327ee-e8a9-4e5b-8b93-4dcaa90e1102	\N
1905084	\N	66	f	d8e7125a-7478-4a4d-bb25-591005201f22	\N
1905084	\N	66	f	27f6d293-47a6-4541-b700-0e6a297bcb72	\N
1905084	\N	66	f	665500b0-3cb1-4244-8939-1d84ea51d08b	\N
1905084	\N	66	f	9693c1ee-1ad2-4fe2-96e1-a94c10331e43	\N
1905084	\N	66	f	dfe455ce-ded2-4136-a0f1-599e31b06c21	\N
1905084	\N	66	f	cf217c1a-bc41-44be-aef4-340b6d9043d0	\N
1905084	\N	66	f	01116efa-c82d-4354-a0f4-85022cda272b	\N
1905084	\N	66	f	c22608d6-39a4-41e5-88fc-b69ff5410a19	\N
1905084	\N	66	f	dd04cf80-0fe4-47d3-bff3-bd41752cb3cb	\N
1905084	\N	66	f	fe09613e-0ad2-4195-863f-1d4d4a8dfbe9	\N
1905084	\N	66	f	b9ea72f4-9c60-4af7-8198-cdf39fb8db47	\N
1905084	\N	66	f	d9c96625-6f08-4c31-8029-3e412571d34d	\N
1905084	\N	66	f	f1b01fe2-2350-43b6-ad3e-873f6d29f944	\N
1905084	\N	66	f	4e2295dd-62b8-42fb-aa31-7cd99e9e624a	\N
1905084	\N	66	f	3f294663-e275-417f-8033-5ac87190cbae	\N
1905084	\N	66	f	91b02ea7-db4e-4216-91c8-dbf1392f380a	\N
1905084	\N	66	f	35a2ce4d-79f4-45f8-9509-98ac8d3e14ff	\N
1905084	\N	66	f	7ec7c48e-1bae-448b-b711-651d238ef861	\N
1905084	\N	66	f	6473448a-4279-4a70-8385-26d5a180f5ca	\N
1905084	\N	66	f	67d206f1-077e-4ec9-ac6c-eeee968e82ad	\N
1905084	\N	66	f	b8707cae-6dd7-4e47-85b1-2356161fa4d2	\N
1905084	\N	66	f	2434432b-710d-4acf-b820-e2562d0d27dc	\N
1905084	\N	66	f	cf8b00c2-1f18-4436-a860-e668031966e2	\N
1905084	\N	66	f	b125d947-f946-410c-95a5-f0f35e450e38	\N
1905084	\N	66	f	cc2cef32-a9ef-4638-bca4-c69a20159832	\N
1905084	\N	66	f	8f4df08d-3c0f-4eba-ac0a-70d8b6b5bf53	\N
1905084	\N	66	f	e6aeaa0a-236b-4da8-8a3b-6ef53eef551b	\N
1905084	\N	66	f	62ea3751-03fb-4330-a9dd-fdde93767530	\N
1905084	\N	66	f	9ea292c1-27b6-45de-a777-982654d57c68	\N
1905084	\N	66	f	b56123d4-780b-4121-b2a2-b1f9d6459b2a	\N
1905084	\N	66	f	5960dd75-55c0-4c7f-9fbb-f722a10f394c	\N
1905084	\N	66	f	bd822a4e-8735-4def-a646-25f69df0951b	\N
1905084	\N	66	f	9930dc73-a484-4105-82d4-b0f3d4ebd4a1	\N
1905084	\N	66	f	ffb9e319-f730-4e33-89fd-71d113c0e964	\N
1905084	\N	66	f	1785d8f2-f262-427c-a14c-2328bcd3dc05	\N
1905084	\N	66	f	5072564a-3e99-49ff-9f6e-372ef6a859a7	\N
1905084	\N	66	f	a7301ad1-4b2f-4c91-8091-8448d5c64048	\N
1905084	\N	66	f	5aafbb29-19ee-4c0d-92e1-aa23f93f9d44	\N
1905084	\N	66	f	9786091a-268d-49a3-acd4-4e9c23f4e411	\N
1905084	\N	66	f	e9534809-8f9b-41a6-be40-ab34c481882c	\N
1905084	\N	66	f	4eb6fbf0-6a23-4ed7-8f51-9a500cae2309	\N
1905084	\N	66	f	d3d932e8-02e2-456e-9f15-12af8a43ad8b	\N
1905084	\N	66	f	df48f3a8-7413-4c49-bc09-8f6e177df763	\N
1905084	\N	66	f	92262b40-b072-4da3-8a51-5bf1d6118f8b	\N
1905084	\N	66	f	319bb7b1-40a8-404e-ad4d-6a17f24aac8e	\N
1905084	\N	66	f	f2046056-5777-416a-acfd-f29109974bbf	\N
1905084	\N	66	f	e28919a6-637e-4c8c-8dd4-89937400ac82	\N
1905084	\N	66	f	c172ff6a-d58a-4a0d-9925-e8b84bd20491	\N
1905084	\N	66	f	34be9aae-380e-4c52-aae6-7da5522b9c0c	\N
1905084	\N	66	f	d02cd976-6de8-41e8-9438-3a5cf89a1dd2	\N
1905084	\N	66	f	4ad68da1-fb90-49dc-bb77-966aed42aaa7	\N
1905084	\N	66	f	43b1f817-ca07-44ef-a460-37f753383815	\N
1905084	\N	66	f	0835620e-4ecc-46dd-9e6b-ea0a625148f4	\N
1905084	\N	66	f	7c9580fc-4cd3-4436-b8a2-1805c506acb1	\N
1905084	\N	66	f	255742f0-3a29-4fa1-816b-c2c2e67bb5ed	\N
1905084	\N	66	f	431edee3-a443-4728-bb92-c13d6d210191	\N
1905084	\N	66	f	ec66ea81-ab1d-41da-b606-d4eece502314	\N
1905084	\N	66	f	4a07c582-d78d-449e-89ad-3441187f5b28	\N
1905084	\N	66	f	6755cb5b-b1ba-4642-a43b-df9c14c5d870	\N
1905084	\N	66	f	ed4339db-45cc-407f-a530-e482b50b6d99	\N
1905084	\N	66	f	7918356e-94b1-4856-a7ad-bebb296dc0da	\N
1905084	\N	66	f	95409674-3d7e-4688-b77d-5cd72bd2147c	\N
1905084	\N	66	f	27eff71b-b174-4c1a-ac04-843d01a75c64	\N
1905084	\N	66	f	07b9a50a-c759-46c8-a776-06565f929a34	\N
1905084	\N	66	f	c6bf9acb-f31f-4d41-972c-afd0781a04f0	\N
1905084	\N	66	f	d90ce544-f63c-4780-819a-f063eb83e2e5	\N
1905084	\N	66	f	4f844e3f-6431-4924-8ba9-543c4ba82015	\N
1905084	\N	66	f	49323331-31e8-483d-917a-795e1e1136c0	\N
1905084	\N	66	f	1d25d04e-de2f-40ea-ab16-136e5b6b27c4	\N
1905084	\N	66	f	7ba8a537-3493-4a22-b4a1-28ad715548f8	\N
1905084	\N	66	f	19e81df9-4db1-40a8-b3c9-1e9ce5c547ed	\N
1905084	\N	66	f	ade3044a-6c8c-46b9-87d6-08df5eb43a79	\N
1905084	\N	66	f	44bbd06f-3a4e-4741-9b46-115129af9b1f	\N
1905084	\N	66	f	859e9f18-25b8-4485-ac35-bddee29be527	\N
1905084	\N	66	f	72136da8-0292-4df4-97fb-8788d8e2935c	\N
1905084	\N	66	f	a32a909f-a7f4-4a6e-b0a9-f2524217021c	\N
1905084	\N	66	f	54457378-84dc-4544-92ee-ec6b091b0458	\N
1905084	\N	66	f	2f26320a-c013-408a-8981-c4ce7f77a0be	\N
1905084	\N	66	f	8853f732-5a05-4813-8737-42544be0b127	\N
1905084	\N	66	f	b74a23f9-6a92-48d0-899c-164ab1c65998	\N
1905084	\N	66	f	cdc8da09-6f30-4ed5-a88d-081a52a08ef3	\N
1905084	\N	66	f	0755354b-bd74-4926-a27e-6f297bd21399	\N
1905084	\N	66	f	e7fc862d-2f69-4adf-9ce1-700c1a802cdf	\N
1905084	\N	66	f	55e025e2-7970-48ee-91bc-a2efd7449530	\N
1905084	\N	66	f	ba76cf03-fd41-4854-b899-ba9a2a2aa979	\N
1905084	\N	66	f	b93d302c-4b4d-486c-b051-fd81385733df	\N
1905084	\N	66	f	156824f3-c20c-4a77-bd78-4b1407f285aa	\N
1905084	\N	66	f	7c157abd-61cd-4ee7-bc54-74d788880efa	\N
1905084	\N	66	f	7fb437fe-03cd-41d8-8461-4ec31203add6	\N
1905084	\N	66	f	c1b224b0-4bdc-47d0-9304-ea2ceaa5d179	\N
1905084	\N	66	f	c4a0231d-6c61-47fd-b8b7-c3b620ddc474	\N
1905084	\N	66	f	34d87f6a-aed8-4af7-ac65-ae11880f5b28	\N
1905084	\N	66	f	1fbfd7ad-23e1-4349-b821-13a8f5dd2c15	\N
1905084	\N	66	f	e7e3093e-6aba-4c85-a9f2-addc322fa394	\N
1905084	\N	66	f	c5d9702f-a3f7-4ca9-8f64-ceea1de4bcec	\N
1905084	\N	66	f	00353cbb-919a-4ccc-9f67-0f2225c25fa5	\N
1905084	\N	66	f	1a0753a2-929a-43c2-bfd9-2c5214247d88	\N
1905084	\N	66	f	2a1f8d7c-0371-4206-86d0-4fb8017c8363	\N
1905084	\N	66	f	75aa1f7f-9c46-4de7-adbe-0a146cba165d	\N
1905084	\N	66	f	95181cc6-4a65-4007-9f40-50f81c11606b	\N
1905084	\N	66	f	29b62c28-1f9f-4945-8fba-d916247dba35	\N
1905084	\N	66	f	5fc974a7-5835-4567-bf62-33e4221827c4	\N
1905084	\N	66	f	bd6da783-3893-4b79-8cff-907e46e887fc	\N
1905084	\N	66	f	2fbb2d8f-14b0-4ac0-bae4-617fdff44ae4	\N
1905084	\N	66	f	71f9bc79-6fdb-46be-a11d-c35816015cc3	\N
1905084	\N	66	f	42ff8aff-20c2-4311-a1b5-9f2d2e2f1e8e	\N
1905084	\N	66	f	441dcac3-d7bc-4f3f-8867-aeb45d08f6b0	\N
1905084	\N	66	f	c9693d6f-ca11-4ad7-814c-4312b18fd2c1	\N
1905084	\N	66	f	c6bcbdbb-1068-459c-8ea1-57b1e03d21bf	\N
1905084	\N	66	f	e8a31611-9778-4ff6-8211-091261bb5518	\N
1905084	\N	66	f	407006b7-b96a-4800-83d2-7dc4777ed21b	\N
1905084	\N	66	f	cd2c3d93-d931-46ad-a00c-f3ce0d1bc30a	\N
1905084	\N	66	f	80a256b7-b58a-4c90-9ce6-6d67de77df2f	\N
1905084	\N	66	f	ecccbe43-4293-440c-93f8-63df4e7cb033	\N
1905084	\N	66	f	4216924d-74fa-4635-bed7-84fce9c10862	\N
1905084	\N	66	f	14c2b070-c583-43f1-990e-9837e0468093	\N
1905084	\N	66	f	8f474b60-72c1-4254-a109-bdfed6877b3d	\N
1905084	\N	66	f	7b6a9fd6-5fb1-43c7-b84c-ded89d6d9ed0	\N
1905084	\N	66	f	6cd5974c-4a56-473a-a44d-7d4a72a83515	\N
1905084	\N	66	f	8d9ebfe3-1867-4e63-9614-c825466e48e6	\N
1905084	\N	66	f	113b7943-3e3c-4e83-b8f0-b6af322131fc	\N
1905084	\N	66	f	3c8cfe44-41e7-483a-9255-e4b39ab7ab15	\N
1905084	\N	66	f	513893ba-5be2-426e-aee0-58032ae03bcf	\N
1905084	\N	66	f	4f0f4aa4-392b-4edf-847a-a92dcbac3990	\N
1905084	\N	66	f	99f136ec-9569-4492-9c26-f8f8100b4720	\N
1905084	\N	66	f	f720a45f-ae58-4aa4-b45c-fc99c663d09a	\N
1905084	\N	66	f	07035fc9-87b3-4bbe-b296-0e74e0f5b2ab	\N
1905077	\N	67	f	d180df1c-9725-4066-9635-873e8f1e23bc	\N
1905077	\N	67	f	bca6d8e5-9a98-40f1-a8f7-7efcb989cc36	\N
1905077	\N	67	f	f08b5bc2-06f0-4271-813b-2fb2b5b87ae6	\N
1905077	\N	67	f	a709390d-2a4b-4036-ba46-888784be4ca9	\N
1905077	\N	67	f	acd8871c-83bb-43d2-845f-39df44ed4c4f	\N
1905077	\N	67	f	18c5cae2-3c36-4b68-bec1-afcf9fe7400a	\N
1905077	\N	67	f	0e95fcdd-a79e-4876-a021-fee5b204615f	\N
1905077	\N	67	f	6378b0c4-431d-48b5-a078-93301a66cb34	\N
1905077	\N	67	f	525bf8ed-ad95-44b3-9446-9954d1fe9bd8	\N
1905077	\N	67	f	316b02b1-6b50-4f42-9ee9-46823a6cb7d1	\N
1905077	\N	67	f	8bf73267-0e92-4e0d-920d-35a2e7d4a4da	\N
1905077	\N	67	f	8a5d2db6-387b-46bb-b69f-104adb8485f0	\N
1905077	\N	67	f	f8351680-4ada-4dea-aa6e-b75c54cc2fcb	\N
1905077	\N	67	f	cde93d85-e578-42d6-a769-850b031c21e2	\N
1905077	\N	67	f	609759c3-63e5-4614-ad22-17c6178f3cc2	\N
1905077	\N	67	f	7abf04fc-9c08-4067-8c1e-0ca976393f11	\N
1905077	\N	67	f	dc84fb4a-e833-40c8-96b3-4e7462504591	\N
1905077	\N	67	f	fb6faf5f-cbb0-4f22-b6fe-4e5282b6eb5b	\N
1905077	\N	67	f	a827f06e-2a91-46e4-a7c2-d8484922e9c5	\N
1905077	\N	67	f	0d4963a2-6c49-4385-84a4-0d6dd2c38ae1	\N
1905077	\N	67	f	06ae1488-b86d-4c92-9914-b22e46f24970	\N
1905077	\N	67	f	5f181df9-ab43-4ebd-bfdf-877b093bde1c	\N
1905077	\N	67	f	29d02c88-4578-40c7-b0af-522139f2bbfd	\N
1905077	\N	67	f	7e456203-0a6a-4275-9d81-0f9b19c3233d	\N
1905077	\N	67	f	9b98addf-c6d6-4ce5-a9e4-0bfa99911ec8	\N
1905077	\N	67	f	b5173bb9-11ab-4682-b366-c447905fbb86	\N
1905077	\N	67	f	9a286ac3-2c57-44dc-821a-e3cd4a79ef86	\N
1905077	\N	67	f	f2eb10b7-b9cc-49d8-ab49-3318d11eff40	\N
1905077	\N	67	f	4710ad52-421b-49f5-b71b-e982c6eaed74	\N
1905077	\N	67	f	f5c80fe8-5c69-4cd8-b9ed-935824f81d54	\N
1905077	\N	67	f	c6c62e5c-cbdc-47a5-a060-64e818c923b5	\N
1905077	\N	67	f	b63c86d5-f6a1-470d-a5b6-4861f6bf775b	\N
1905077	\N	67	f	32243af6-aec5-4047-ad7c-b7e6052ae153	\N
1905077	\N	67	f	fdcdba30-b1bb-425d-b8f8-79d21140600a	\N
1905077	\N	67	f	10e6cd0e-4daf-4ccb-9e42-f7da7b569bc5	\N
1905077	\N	67	f	9192bac0-3d60-49b0-9c79-ca4fffe6fdb6	\N
1905077	\N	67	f	14f29338-0b7f-4c7e-90c7-2fc516941b54	\N
1905077	\N	67	f	ae74dbc8-7341-4cb5-81b5-43c0d12c7cf1	\N
1905077	\N	67	f	c590d1bd-4b97-494b-af57-021e8faf049f	\N
1905077	\N	67	f	b0a94eaf-a7b0-4003-a597-7dada36e5d48	\N
1905077	\N	67	f	19aef12a-ae67-431e-8d41-9fd50d898f08	\N
1905077	\N	67	f	f561e2a2-692d-4da3-8250-d6c61e7d01a9	\N
1905077	\N	67	f	af51cae1-8f92-414f-b420-dffda012f0f7	\N
1905077	\N	67	f	c76d1f56-01df-4368-99aa-89835ba511d2	\N
1905077	\N	67	f	94ff8ee3-1d8e-4ad8-9f78-f393c2e2226a	\N
1905077	\N	67	f	ac98069f-d130-462a-aeea-be99e6fcad30	\N
1905077	\N	67	f	7f973cee-858f-4796-ad33-1d9e1691545d	\N
1905077	\N	67	f	8ed23ca8-bd8e-494a-9147-173694272cb2	\N
1905077	\N	67	f	c610e489-ec38-4edc-8b5b-198d0dc739d0	\N
1905077	\N	67	f	26991d65-d99f-4daf-a0ca-818d253e0c25	\N
1905077	\N	67	f	192f3b0f-ef5b-414f-af19-4878e6aa5f21	\N
1905077	\N	67	f	71bf8e8e-588e-468b-9a4d-264519dc3c4b	\N
1905077	\N	67	f	aaeb2f39-1bda-4fdc-b813-63846641dccf	\N
1905077	\N	67	f	b9e2e872-0737-401f-87cc-959763028c8d	\N
1905077	\N	67	f	cc67bd7d-7817-41f2-bbfb-2ef1518a8af7	\N
1905077	\N	67	f	fc63b743-9fc5-40ed-ab5c-159441cb524f	\N
1905077	\N	67	f	8e111f93-77bf-4a03-aeb4-818f9a890d04	\N
1905077	\N	67	f	1c870a97-de9f-4575-b5f3-8d7ffe8e3072	\N
1905077	\N	67	f	f55fcbfc-a3b1-4e4d-a41a-1f9fc00c2fb5	\N
1905077	\N	67	f	3289f400-7973-434b-bf17-962303b7ab8a	\N
1905077	\N	67	f	94d333e5-af63-4b25-811e-09865b52769c	\N
1905077	\N	67	f	02dc825b-7a98-4668-b3c6-2a1882e56a20	\N
1905077	\N	67	f	39674acd-effa-4a97-8859-5e37aa410850	\N
1905077	\N	67	f	354c2cb0-8904-4c77-a1db-c42b93cbcadd	\N
1905077	\N	67	f	f48052a8-74ea-4c5c-ab80-9da40e62b2a7	\N
1905077	\N	67	f	e16e1f69-8608-477a-a61e-672cb86b23b5	\N
1905077	\N	67	f	05b5fd83-a228-400a-8137-63be644ba6e3	\N
1905077	\N	67	f	268a2c46-bc6e-45db-9dcc-11f1dae5e420	\N
1905077	\N	67	f	c04cb5dc-e425-4f51-99ce-de8183c90f24	\N
1905077	\N	67	f	85e506d3-fa4a-41d6-9ded-d4921e4593ac	\N
1905077	\N	67	f	350b2e84-9e2f-4005-a0a6-bfb6f9493f9c	\N
1905077	\N	67	f	97af96f8-bf10-4e33-acef-533def6507cd	\N
1905077	\N	67	f	e35c42f0-9d4e-48b2-8363-842b60d3b404	\N
1905077	\N	67	f	4c5fa440-fb94-46ad-8999-dbc8d54a6abc	\N
1905077	\N	67	f	5e4fafa7-8f46-4cbf-a765-1006b2a4965a	\N
1905077	\N	67	f	c6158901-1ad9-4137-a05d-c669fcd6f7ff	\N
1905077	\N	67	f	35a4043c-9c87-437e-802e-49748d6c9c1c	\N
1905077	\N	67	f	c73e7b1c-c5a2-4ec8-a34c-3c023295a63e	\N
1905077	\N	67	f	e85706bf-4af3-448c-ab87-e1b15bc5b709	\N
1905077	\N	67	f	e73473e4-409b-456c-a76f-d1154ce61309	\N
1905077	\N	67	f	a4e2acb8-84b6-45db-9f6e-9592d1fbf344	\N
1905077	\N	67	f	74502c3c-487d-42dd-85e0-11efb6f896b0	\N
1905077	\N	67	f	ced6d41d-e4d3-48ec-a949-bb1bddaf810f	\N
1905077	\N	67	f	e3ac6d8e-c69d-4314-9af1-847ec5e771a2	\N
1905077	\N	67	f	f105789d-0820-4de0-99f8-99c59dce0a2d	\N
1905077	\N	67	f	594dde3a-73fb-40e1-a62f-2617403a8892	\N
1905077	\N	67	f	5b53323f-0090-41dd-b3d7-c770883b2a0b	\N
1905077	\N	67	f	65706ba0-6113-40b8-a7b5-91c464291de4	\N
1905077	\N	67	f	1ff222b9-725b-4b53-9c6a-67fecd545d99	\N
1905077	\N	67	f	6cc5392e-dac0-4e7e-aa10-572aa8949905	\N
1905077	\N	67	f	fdd004f6-0ed4-4be8-8e9f-c2b7c6efaba1	\N
1905077	\N	67	f	4324c1ed-b8c6-4321-84a7-8cfe4fdb7eec	\N
1905077	\N	67	f	f22e0714-acfe-46b7-bbad-7914c743df2c	\N
1905077	\N	67	f	b7790a7f-5fb3-42a9-a359-622b6449d92d	\N
1905077	\N	67	f	f6a96fb5-5680-464e-9d7e-479dac74af06	\N
1905077	\N	67	f	e2e08a74-f2b2-492e-a60d-64ca4810106b	\N
1905077	\N	67	f	4a8a2303-b821-49e8-a543-8effd7cee9e2	\N
1905077	\N	67	f	6cd122ad-7497-41f8-9bd3-09e87ecaa119	\N
1905077	\N	67	f	b6daa762-825d-40d1-bf8d-374149aa880c	\N
1905077	\N	67	f	70a75cab-928f-47fd-9b4d-9b52b3496421	\N
1905077	\N	67	f	5d862bdc-708d-4cf0-a89a-2af379fb550e	\N
1905077	\N	67	f	76e655e1-63b7-45b0-b4e3-a20ba77b502f	\N
1905077	\N	67	f	66c937a5-5298-4dc3-8ca2-7e3d9f45918b	\N
1905077	\N	67	f	6c467347-af03-4cbc-a989-e4b49db22603	\N
1905077	\N	67	f	d47cfe25-b598-4f28-b7ae-2a6d688eae11	\N
1905077	\N	67	f	4f497ae6-31b9-4ee4-8f5c-d9314aef560a	\N
1905077	\N	67	f	eab6b862-1bc8-4261-ade5-f95d452a8b1a	\N
1905077	\N	67	f	6f674294-c9d9-4828-b500-16ab9ecb555b	\N
1905077	\N	67	f	69284ca7-fc2a-4ede-aadd-3d8b7981af8e	\N
1905077	\N	67	f	336e4205-a3e1-4dc3-b6fc-cbf8e12f8147	\N
1905077	\N	67	f	942fa2ef-7f9b-492f-a215-2982e408a8e7	\N
1905077	\N	67	f	ddc77168-ab13-4a7c-a774-1b88489b5c3d	\N
1905077	\N	67	f	41fd00ee-2de0-444d-9c5a-35121cd875d0	\N
1905077	\N	67	f	1daacbc2-c9a6-4341-a4ac-d914e88fd8e8	\N
1905077	\N	67	f	4acfe932-89e7-47b9-abeb-09c98d6bcaec	\N
1905077	\N	67	f	715fb35d-cd6e-4f23-bea3-3cfdf96cff87	\N
1905077	\N	67	f	5a5fc352-ef41-4285-9b71-0b160d292566	\N
1905077	\N	67	f	9480af20-a130-40b6-906e-9f67314f9616	\N
1905077	\N	67	f	48197f4f-4245-4d95-b33c-155094242eca	\N
1905077	\N	67	f	c5d1b7b4-b809-4995-ad17-473749e98c8d	\N
1905077	\N	67	f	95e50e6b-d128-46dd-9677-d65a276a0447	\N
1905077	\N	67	f	97f01083-3f83-457c-8848-f4b8e267d57c	\N
1905077	\N	67	f	adaa05f6-b7a4-4d77-8da2-3e582f27de4a	\N
1905077	\N	67	f	46c2f306-7e73-449d-bf2f-8241c0526c9c	\N
1905077	\N	67	f	d97838d8-8a5a-4cce-9719-36c0e641a7a6	\N
1905077	\N	67	f	7344d37e-0a8c-4b12-99cb-93e6514abdd5	\N
1905077	\N	67	f	552a0a15-335b-4060-b904-b1a23708794b	\N
1905077	\N	67	f	24742734-9110-4394-88b3-6ee2689ab4ca	\N
1905077	\N	67	f	b0d63573-2060-41fc-aede-9d39a6d89dcb	\N
1905077	\N	67	f	352f2f11-9ace-49be-8f0e-a2392f0316c8	\N
1905077	\N	67	f	fe1fafb9-fe07-485b-9438-d9aa19d10f17	\N
1905077	\N	67	f	c896ffc1-3861-459f-a517-225169a91381	\N
1905077	\N	67	f	ab2b5f09-fc87-41cd-aae5-3163f8e73056	\N
1905077	\N	67	f	8a05e4ae-a79c-4d10-9202-59bdf6aef74b	\N
1905077	\N	67	f	1f5e5142-965c-4073-889c-757a25419d68	\N
1905077	\N	67	f	be7deffc-a3d3-4cf3-a5f5-bf8867e17866	\N
1905077	\N	67	f	339e8298-4e9b-4b5d-b974-2eb2ea89cf73	\N
1905077	\N	67	f	3a35141c-d2a3-4c61-9861-8a7a6a44bcaa	\N
1905077	\N	67	f	41fcde7b-7c89-4638-a64c-d823d17f4c1f	\N
1905077	\N	67	f	37827d7e-0fef-4d7a-af02-6e05e1c56a46	\N
1905077	\N	67	f	0050f4cc-c19f-490d-8714-2bf830887a79	\N
1905077	\N	67	f	ed9ca6b4-9ae3-4f7e-8406-bef08a3f0c34	\N
1905077	\N	67	f	106c3b1a-77ad-4e95-a476-7703a65842fe	\N
1905077	\N	67	f	8ec3afbb-33b2-428d-8eef-d77a5e9acde8	\N
1905077	\N	67	f	373b8718-263f-4a14-bf62-733f362c460e	\N
1905077	\N	67	f	2ce16746-4e10-4fde-949b-65ce07559943	\N
1905077	\N	67	f	e879cb3c-29a5-4757-8e30-991123921b26	\N
1905077	\N	67	f	d204e551-b17e-403a-aa84-292c22d2f551	\N
1905077	\N	67	f	c2d9d2f2-6fb4-4bba-a7d3-2786fd862857	\N
1905077	\N	67	f	fd4c995e-152d-4c29-81dc-1ea75b8f0c45	\N
1905077	\N	67	f	eabc50fc-6915-4992-8134-d05661df89fa	\N
1905077	\N	67	f	a3c3fcb5-59fd-49f7-82ad-c7098813ff71	\N
1905077	\N	67	f	9d81e6af-1a50-4b05-a2d7-c2e86d877861	\N
1905077	\N	67	f	6916a33e-b537-4386-a5a2-6ee3de4fcaa2	\N
1905077	\N	67	f	8759dc3e-5e5b-4ed9-a34b-694a925879de	\N
1905077	\N	67	f	97ee58d1-901a-48e3-a028-0655a626b2fa	\N
1905077	\N	67	f	67cbf655-6c08-4389-8129-a86b3e883ea8	\N
1905077	\N	67	f	66e749ac-8e35-4353-8750-1ec0b4b46ec7	\N
1905077	\N	67	f	072c0678-7a10-4b05-854a-a28c53292c5d	\N
1905077	\N	67	f	b1fcdb53-1083-4d10-ba8b-afc06eb5d15d	\N
1905077	\N	67	f	237216eb-82d2-417d-add8-4dd8671beec9	\N
1905077	\N	67	f	f368409b-fa2b-417a-812d-38c7b5613934	\N
1905077	\N	67	f	fd6437d6-8580-4dbc-8371-dd86f12fd2cf	\N
1905077	\N	67	f	ec77a60d-bbf8-40eb-ac1c-eab284a1a2bc	\N
1905077	\N	67	f	bfc7512a-e268-4f89-908a-9f7f50c03a68	\N
1905077	\N	67	f	1b3b8ba9-92ae-40bd-babd-4e9c26e1ab12	\N
1905077	\N	67	f	8349c691-6a32-4ee1-b71a-6e4b89319340	\N
1905077	\N	67	f	6e463043-e1b8-4613-832c-cbc6771f77e7	\N
1905077	\N	67	f	74ce5f32-a36e-4847-b756-77b3e5488f11	\N
1905077	\N	67	f	2fffecd1-f811-4b7f-b585-f44cc37b63ad	\N
1905077	\N	67	f	3a98f30f-799e-434c-8218-648c67b14363	\N
1905077	\N	67	f	0cd7bbc7-3b64-4934-826c-0fadffb8c71b	\N
1905077	\N	67	f	738dda1b-f0f3-471e-8d24-3b57831b5eaa	\N
1905077	\N	67	f	52637d68-b3f6-4182-aefc-d5682bfbc428	\N
1905077	\N	67	f	2cd5476b-5cee-4d15-b1f5-26c6da49601d	\N
1905077	\N	67	f	0dc57636-b2fa-499b-befa-39b19ff06098	\N
1905077	\N	67	f	5c52f8f5-abc3-4d4b-92a3-99250bc487c8	\N
1905077	\N	67	f	0ae659f0-32fc-4b77-8ddc-5215a6005667	\N
1905077	\N	67	f	fc7e0078-3915-4fd3-a8eb-57e4ea8b553c	\N
1905077	\N	67	f	b996fdd2-7e33-4e75-b389-ece98de41d71	\N
1905077	\N	67	f	405a191f-f800-4e70-8f95-2d6eec3645db	\N
1905077	\N	67	f	55504093-dd9b-4077-bb5f-6ddcb0c1b93e	\N
1905077	\N	67	f	b8e26fd7-8c6e-47e9-b12c-4a410d6dff6b	\N
1905077	\N	67	f	9c147566-fe5d-40df-99f3-69a2b267ef0e	\N
1905077	\N	67	f	30ac1767-6b1e-420c-8fcd-7ec37b31a560	\N
1905077	\N	67	f	a5f6b105-4f72-44fa-8b52-a12a0ce61586	\N
1905077	\N	67	f	ff625dfa-4fcf-430e-8aba-964d60d156e1	\N
1905077	\N	67	f	f774c741-0f5f-4f31-a7f0-659d15a17c5c	\N
1905077	\N	67	f	b4eb73c3-59d4-471c-9618-46816b5f0461	\N
1905077	\N	67	f	f5e5125a-c51c-4bf5-9c4f-21bb3710dadd	\N
1905077	\N	67	f	cff43c24-46d8-468d-959e-066b8e1631cd	\N
1905077	\N	67	f	e561a13d-1156-4872-8cc3-a58fd93dd36b	\N
1905077	\N	67	f	139359a6-a011-402c-a23d-6ecaea39d32c	\N
1905077	\N	67	f	c169001f-a4a3-4922-89f3-7239d34b9f20	\N
1905077	\N	67	f	d6b64689-c703-4b1d-af2d-3f1ebbee7f73	\N
1905077	\N	67	f	13b625a5-ed14-44bf-b510-ca44691c58ee	\N
1905077	\N	67	f	f376b190-e9fb-4a93-ac57-1ee862af35d7	\N
1905077	\N	67	f	d07af3da-9252-48d2-a4e1-09cf7abbd03a	\N
1905077	\N	67	f	7af2be7d-d32f-462c-94a2-3ce4dd580ab1	\N
1905077	\N	67	f	32fe70dc-93fa-4ab5-a67a-3abbbbd0ae52	\N
1905077	\N	67	f	115e7497-fd30-40d5-8fb8-c369c4098e02	\N
1905077	\N	67	f	55e2b026-2457-4e54-b6e2-c4aaaeba17d5	\N
1905077	\N	67	f	827b066e-ec2d-4fbd-8366-d5325fbce2a5	\N
1905077	\N	67	f	4fe5a096-5cf4-4e32-9c7e-44e58fa449f3	\N
1905077	\N	67	f	a3b4470b-21eb-48ff-8e2b-a8e72e70a619	\N
1905077	\N	67	f	72386a89-1e5d-4d1a-9988-c46ef1c1284e	\N
1905077	\N	67	f	fece97a3-85b7-426e-9783-002313f2de42	\N
1905077	\N	67	f	9eeec12a-a679-48ba-a48a-c8a88facfa94	\N
1905077	\N	67	f	fc2773b9-c6ac-474b-bb0f-8a14f8277cbb	\N
1905077	\N	67	f	6f359744-58a1-4565-a2c4-37a437ceacd3	\N
1905077	\N	67	f	7c9ae786-4f87-4576-9c68-be2e8cb1e254	\N
1905077	\N	67	f	ed53c16a-accc-4d5a-8f46-34dc9e279a4d	\N
1905077	\N	67	f	95ab43b7-94f3-421f-88dd-83cf450e430f	\N
1905077	\N	67	f	fc739a12-476f-4336-819e-47d58842adc2	\N
1905077	\N	67	f	8984f9a1-0f5e-4c87-ac81-bc590c864196	\N
1905077	\N	67	f	a6726e86-ad7d-4cb1-a88b-d8743860b3bd	\N
1905077	\N	67	f	bf0e598b-4614-48a4-a310-e03c73e3f80b	\N
1905077	\N	67	f	8a1574bd-32cc-40d3-9542-74749b82613d	\N
1905077	\N	67	f	aabf1cb4-fe43-4e01-af5d-6681f0318a3c	\N
1905077	\N	67	f	9196cbd2-f8e8-45f5-bd34-45fabe1246af	\N
1905077	\N	67	f	0b157b2f-f8da-4ad7-95e0-c3990ec95441	\N
1905077	\N	67	f	aa5b256c-9234-47e0-abcb-3368a46e759b	\N
1905077	\N	67	f	8e76f163-6fcb-4819-927a-56831c5f68a7	\N
1905077	\N	67	f	227dbb6f-07b4-4843-9fbf-02afbfedb199	\N
1905077	\N	67	f	76a38a77-2cae-4ee3-a51a-dc287cab5da3	\N
1905077	\N	67	f	28b14449-52c4-46f0-b547-418d5a9c9343	\N
1905077	\N	67	f	65290b4a-0348-466b-bb66-8acca7f53cb5	\N
1905077	\N	67	f	7978d3cb-6965-49a0-a607-1bde3b1ce48f	\N
1905077	\N	67	f	8e781b89-4025-4f0f-bcce-bec7e94eaa5b	\N
1905077	\N	67	f	e60e7fba-fc86-481d-b5c3-7f3697787743	\N
1905077	\N	67	f	92bdb4b0-32c8-4b9b-b576-b6648098e9fb	\N
1905077	\N	67	f	6e5badfe-bad2-4617-98a7-a9e30e966cd6	\N
1905077	\N	67	f	a51e4afe-9c25-40bc-b86b-c77c4039acf0	\N
1905077	\N	67	f	3fc09c7f-5759-4234-aa90-6b979e22d3c9	\N
1905077	\N	67	f	2e495b3f-a50b-4ad3-b465-e3fa6fd42160	\N
1905077	\N	67	f	c3551922-e489-470e-9490-36d907efb47f	\N
1905077	\N	67	f	6e68d374-abf9-4537-85c1-84173cee3a18	\N
1905077	\N	67	f	40c81200-9f70-4f6c-b630-900ac8a6b910	\N
1905077	\N	67	f	f2ad04f8-928a-4740-be97-f494a2090c3a	\N
1905077	\N	67	f	ee5c4208-d855-4bf1-a0dd-fd7b237c0dac	\N
1905077	\N	67	f	6b77345a-9fd9-4451-aa6c-6edbf49a1af0	\N
1905077	\N	67	f	f383adcb-2801-46b2-98e6-65c08fed6266	\N
1905077	\N	67	f	0b424a86-6ad3-4ac4-b167-bb40de6653ee	\N
1905077	\N	67	f	d23e98e7-35d8-4189-8ac4-d7fea5e1454d	\N
1905077	\N	67	f	baefc84f-12ef-4d39-9cd0-fdfccdd2a9db	\N
1905077	\N	67	f	a52ae1af-d8ae-4158-8a00-5e8e8b44b797	\N
1905077	\N	67	f	56793909-a29d-46d2-8394-5a97bee13bb5	\N
1905077	\N	67	f	776890b9-680c-4a89-a60b-af47680d23a4	\N
1905077	\N	67	f	a6e40406-de98-41f3-8308-288c20ff4c46	\N
1905077	\N	67	f	cb4f2052-1833-400c-8219-78cd60e3f746	\N
1905077	\N	67	f	6a6e9d54-2ca5-4211-8bbe-848c25220794	\N
1905077	\N	67	f	5629601c-6652-490c-b325-5165bc78369c	\N
1905077	\N	67	f	81d85568-a585-4534-ad5c-3a1cd628177f	\N
1905077	\N	67	f	18828067-e1c8-43d0-aa7f-dd6a64beca8c	\N
1905077	\N	67	f	b9f225b7-0a36-4d1f-83d8-b12a848bf1b6	\N
1905077	\N	67	f	2c9cf739-ad38-480f-8282-8f6da00068c4	\N
1905077	\N	67	f	f875527d-b687-4703-aa5f-c55ce338deed	\N
1905077	\N	67	f	56ff83c3-ab6f-4f2e-902e-0bf3818e19d8	\N
1905077	\N	67	f	4ba6ca3d-7d88-4f94-a520-1525a8966221	\N
1905077	\N	67	f	82bc35a8-f910-46e4-b993-850bf911010e	\N
1905077	\N	67	f	ee06b125-4ad1-4381-a285-f5fbe26cec29	\N
1905077	\N	67	f	760dda6f-fb1a-43a5-90d7-9af91ef56d87	\N
1905077	\N	67	f	2168ed7e-4c5a-45f9-9333-542cf8ea0b78	\N
1905077	\N	67	f	ca20cd80-fb1c-41de-b055-e09724adafd2	\N
1905077	\N	67	f	acc81cf3-0aa7-4bd5-ad66-7235ff89227c	\N
1905077	\N	67	f	6fd03f9c-6b82-4246-846c-4456d15cb47a	\N
1905077	\N	67	f	db2b3226-be16-47f1-bb61-826642a02175	\N
1905077	\N	67	f	1a8c75ab-549a-4775-a125-e1f2d08017c8	\N
1905077	\N	67	f	a5c1e7d1-c481-4e93-b4ad-278512a802bc	\N
1905077	\N	67	f	f11e701b-ae68-4b60-8fe8-2ebdf5b9d062	\N
1905077	\N	67	f	8697b942-d492-48e2-8480-6f6d26ce0ea8	\N
1905077	\N	67	f	52a9b728-e00d-4297-aa30-d26657338fbd	\N
1905077	\N	67	f	372d6b43-11b9-4523-828a-a08d05a88505	\N
1905077	\N	67	f	e6d84530-3e6a-4d50-ac07-9686bd190076	\N
1905077	\N	67	f	29561dbb-de5d-4da5-a22c-0cffc5aaa26c	\N
1905077	\N	67	f	c4d4a595-862d-4cb0-bb3b-d1eced174a03	\N
1905077	\N	67	f	ed28d02c-944e-498c-aed0-aeb8e8d65501	\N
1905077	\N	67	f	9cdf0bde-bbfc-42c4-98d8-d8aaf984819b	\N
1905077	\N	67	f	fb315543-fc4e-48b7-9379-3bd5ea1b5b57	\N
1905077	\N	67	f	a481f648-7f91-42ae-ac95-bd444e46478d	\N
1905077	\N	67	f	e429ae61-716e-4b58-b71a-40c43684a1b1	\N
1905077	\N	67	f	799270c9-b9ef-426a-97bb-07c93d757dff	\N
1905077	\N	67	f	a77f1b35-dc5e-4925-a829-bb97ff2147d1	\N
1905077	\N	67	f	02906bf2-c42c-4068-88f2-1018077a959c	\N
1905077	\N	67	f	7968497c-c7a4-4859-92ee-3f807d674fb1	\N
1905077	\N	67	f	bb30c685-d936-4201-8813-010faa61546e	\N
1905077	\N	67	f	92fda03c-c07d-48d0-9c51-08c80476f9d1	\N
1905077	\N	67	f	56b24037-72ac-4f71-b034-dcb21a812cf7	\N
1905077	\N	67	f	9b32ae5d-f7cc-4bed-8be3-aa083f0c55a9	\N
1905077	\N	67	f	0a3c8e2b-2814-45fa-a8a0-546a8cbc1c6d	\N
1905077	\N	67	f	88104358-0742-4f20-8f32-be2809414503	\N
1905077	\N	67	f	596bce5d-c23c-4424-b12d-e4f32b67ad90	\N
1905077	\N	67	f	ba5d7f17-7176-471f-ab86-8a27e83150ea	\N
1905077	\N	67	f	02c0ac8c-4fd7-47bd-95d5-cde8db2290ca	\N
1905077	\N	67	f	ddbeb99a-aec5-4ffc-b1e7-c3e45d5783bd	\N
1905077	\N	67	f	6a18abdc-a0e5-4660-8f99-20db7253f9a2	\N
1905077	\N	67	f	fff9e657-776a-4dfa-b47c-28e4c95fae3d	\N
1905077	\N	67	f	bec72574-7636-4d2d-8ce0-823939eaf882	\N
1905077	\N	67	f	1da16cd2-5df9-4631-9b4f-1b64fd67f564	\N
1905077	\N	67	f	bdbe72a5-54fd-4f8c-9ee7-09f7894b0efe	\N
1905077	\N	67	f	271890b1-fc2a-4485-be9f-57d2420f5d69	\N
1905077	\N	67	f	39271a5f-1259-4381-b129-84e91e0ad824	\N
1905077	\N	67	f	5a6edbe7-ca2c-44d4-9e49-09623281cc4c	\N
1905077	\N	67	f	0ae6ec0f-0fd4-4c9f-9b53-33e5eb09c1be	\N
1905077	\N	67	f	d4890b52-811c-421d-92f8-ae93138032c3	\N
1905077	\N	67	f	8e92abf2-9cfd-44b7-a611-d1bf33e0effc	\N
1905077	\N	67	f	043ca564-de0c-427c-b941-d35845c809d8	\N
1905077	\N	67	f	96800390-c5eb-4b03-8ecc-5d73a2a0ac63	\N
1905077	\N	67	f	e94b6ea5-8574-4eaa-9b86-236804dd9d48	\N
1905077	\N	67	f	55eb300b-fdd8-45fc-a5b8-87b8e9ac7279	\N
1905077	\N	67	f	38442e91-a076-4b20-8975-bbffb43bbc40	\N
1905077	\N	67	f	51274d70-fcb8-4944-954e-fe9b0b705d84	\N
1905077	\N	67	f	44cba7fd-75d1-4091-bac4-f751e714fc0b	\N
1905077	\N	67	f	a2b5039b-e5ca-47df-865c-5549993ba3eb	\N
1905077	\N	67	f	195ef313-c65c-4063-a9ca-77245810ee5f	\N
1905077	\N	67	f	f198c109-2648-48ff-b10b-0fa5387b5ccf	\N
1905077	\N	67	f	fb1c034c-5605-49a5-ba75-bffb5f71a496	\N
1905077	\N	67	f	f7d1b74f-a2d2-4b4e-8495-2241c35d5c84	\N
1905077	\N	67	f	6cf9bc84-30b5-4440-9fef-5f2487aa6d72	\N
1905077	\N	67	f	7533c1d3-69a5-4de8-8937-d6e4d915e587	\N
1905077	\N	67	f	d493e981-d6d6-4ef8-b143-1307253c90f7	\N
1905077	\N	67	f	2da223b4-69f1-4fb0-aa54-687dabd0430f	\N
1905077	\N	67	f	a49206b8-f125-4ba0-9274-294050ffac05	\N
1905077	\N	67	f	babccc18-7cd6-4bd4-a76a-dbeae3d873c0	\N
1905077	\N	67	f	d5a3fe0f-fd33-4150-9605-1dac2c874067	\N
1905077	\N	67	f	7bd7422b-53d1-4685-b88f-7eb49802667d	\N
1905077	\N	67	f	1c76b981-5e60-4a1a-8664-4326793030bf	\N
1905077	\N	67	f	6fba7e7a-5aa4-4cdc-82e9-3d87640287e8	\N
1905077	\N	67	f	ee362d94-11f5-4b36-8009-73febe6035b7	\N
1905077	\N	67	f	59f95c34-4afa-4ac0-b410-fea58c803cb5	\N
1905077	\N	67	f	e84d4eeb-6ff6-42a2-929c-5d12218a4ca3	\N
1905077	\N	67	f	477d47c1-2747-4461-9422-938aedc6f81b	\N
1905077	\N	67	f	7a9e186f-79a3-4f4d-b75a-2e1fdf8be409	\N
1905077	\N	67	f	3fe70bb4-4d49-43f5-b525-55e68b1a3a5c	\N
1905077	\N	67	f	039e894d-0757-47b3-8c0f-48bcc645ade0	\N
1905077	\N	67	f	0d5422ee-47db-4638-9507-7a6df277ee62	\N
1905077	\N	67	f	3937b02c-48f8-4655-a2a2-0cf3f7762a65	\N
1905077	\N	67	f	19e0886f-ab4b-4e34-a7f4-15f0bf15adef	\N
1905077	\N	67	f	daac9437-a124-4d0c-8dab-8ed8114424a3	\N
1905077	\N	67	f	bfd4a9f9-0d97-4926-b8c2-bb7b6f64fbf6	\N
1905077	\N	67	f	a025d705-d3a4-47e9-9bca-da3bd81422f4	\N
1905077	\N	67	f	366f61f8-40de-4dab-9191-30ea152e1608	\N
1905077	\N	67	f	4104f548-d044-4057-84cc-1486644dee7c	\N
1905077	\N	67	f	c58b95b1-68f5-4338-b2ba-cb15cecfab91	\N
1905077	\N	67	f	59a68c29-a73f-4842-b59f-ea1de81e9f02	\N
1905077	\N	67	f	4bf122d9-d821-4fb6-86af-5793fa3cba1a	\N
1905077	\N	67	f	09907806-2a66-43e9-9e4a-ad52363cfd2a	\N
1905077	\N	67	f	1e719b10-3ca6-4179-a1c4-00bf6256334c	\N
1905077	\N	67	f	e53fc823-74bd-430b-ae04-93d232a47a0f	\N
1905077	\N	67	f	9dfa0873-eecc-42f5-b54e-88dcd59659a0	\N
1905077	\N	67	f	08ade896-35bf-4f45-b883-1e5d9b0d2443	\N
1905077	\N	67	f	1db1cd9d-f19f-4405-96c9-09fb2f8d860d	\N
1905077	\N	67	f	ce59db6d-ed6a-40c8-b35a-a0e88e830f85	\N
1905077	\N	67	f	c92a4dd3-50b9-4073-822d-7dd09dc84bb4	\N
1905077	\N	67	f	82f3f2a9-5686-4495-9c2d-35b911e9e7ce	\N
1905077	\N	67	f	878351c1-7dc3-4a77-80c5-2091073d8dab	\N
1905077	\N	67	f	c4346aa0-0087-4913-883f-43aebd52bb24	\N
1905077	\N	67	f	d632699d-a478-4952-9fc7-22653300e385	\N
1905077	\N	67	f	a6aef881-fb05-41f4-8ac2-1c2dec7edefd	\N
1905077	\N	67	f	1cb97beb-1c56-464c-91a9-728600febe84	\N
1905077	\N	67	f	9b847f6b-44c0-4c08-bca8-424416c75ced	\N
1905077	\N	67	f	6d335129-09c0-4beb-9e6d-edf593a2a200	\N
1905077	\N	67	f	3e233d83-dd01-4fb6-9fb9-9f1d78cb7661	\N
1905077	\N	67	f	c679cff4-5eed-4675-8d2b-9daffd3894fe	\N
1905077	\N	67	f	1a152c03-c114-4299-9ace-71c052d3c34d	\N
1905077	\N	67	f	5df6591c-5837-447e-b535-b7fab06f0d7f	\N
1905077	\N	67	f	7771eb55-f6bf-45c1-8cb3-8402b4eab289	\N
1905077	\N	67	f	0bc00bc4-54ea-4b75-80e1-a89b97fd8e87	\N
1905077	\N	67	f	8b64f4b0-caf7-48c3-b796-07594c421639	\N
1905077	\N	67	f	24dc2dc9-e146-4eb8-aa73-f31b389ecd0e	\N
1905077	\N	67	f	fe04ddb4-8b1d-4d6f-8d1a-0775daa2a752	\N
1905077	\N	67	f	13f97bcc-b1d6-4151-8038-71b2de073569	\N
1905077	\N	67	f	8079e9b1-508e-49c0-9fff-e1972e9618f6	\N
1905077	\N	67	f	9f29da75-5b62-41b3-9548-b8d46b3f44a1	\N
1905077	\N	67	f	1f9890f9-f34b-4097-8560-722bd20bec39	\N
1905077	\N	67	f	f8a8dba6-0d91-46b7-a5d5-d8780ffd5f98	\N
1905077	\N	67	f	50733fee-3716-4f6a-82ae-c409640e861d	\N
1905077	\N	67	f	25e5a642-f94a-4b3b-88f2-26fad7c91148	\N
1905077	\N	67	f	de94effc-7658-4865-9961-e21d9a180225	\N
1905077	\N	67	f	daa8bcc9-25ad-4b70-9713-78cef9896aa8	\N
1905077	\N	67	f	5ae7f2ff-0921-41ce-9050-0bc5f9a91626	\N
1905077	\N	67	f	7e203127-acb2-4485-8c5e-f670a6657155	\N
1905077	\N	67	f	c849881f-1e90-428d-a9ac-98b2a216ab26	\N
1905077	\N	67	f	54559bbb-3b40-4f1e-b7aa-c9f08582dd42	\N
1905077	\N	67	f	e6d2f41f-a24d-4388-940e-f274179ef4e4	\N
1905077	\N	67	f	f640b96f-961a-4a9b-b567-faf785bbc0a2	\N
1905077	\N	67	f	4b33b572-0970-40df-a51a-9c78429f91bf	\N
1905077	\N	67	f	ece5fb7c-d3f0-43c7-87fd-d5eea8e72e61	\N
1905077	\N	67	f	92bc5f33-7fd1-48a8-b62c-5229e52268c2	\N
1905077	\N	67	f	4733233f-31a3-4d9d-9901-c316eea87155	\N
1905077	\N	67	f	47ee807d-63b0-4048-98db-256780c3fdc3	\N
1905077	\N	67	f	ec9d9e93-84af-4e1f-8258-408919cdf568	\N
1905077	\N	67	f	247900e3-3a0d-483e-90ae-6c739e3cdd3f	\N
1905077	\N	67	f	ee3549d5-cd4d-4d19-a496-af95c7f99bb7	\N
1905077	\N	67	f	ab52d1f2-801b-40a6-aa3c-47d061045f9b	\N
1905077	\N	67	f	a9d27111-5b17-46f8-824c-b475212da6b7	\N
1905077	\N	67	f	3ec1b04c-b5cc-415d-b19f-d777f681ef2f	\N
1905077	\N	67	f	c866b6d7-e8b8-4dc9-b5be-cde1456e03c6	\N
1905077	\N	67	f	f0125d6f-ba6b-4263-926d-5bebd947c286	\N
1905077	\N	67	f	dbba6396-d65b-4123-8171-ebd9d01c24bf	\N
1905077	\N	67	f	d93ba0b3-e3b3-4889-8e09-e91d4fac4af1	\N
1905077	\N	67	f	7be3a950-1584-4868-a36d-546eafd9b8c6	\N
1905077	\N	67	f	7ff5ffcc-b56f-4565-91d1-7062b8a1e518	\N
1905077	\N	67	f	05dc449d-62b3-4a97-acbe-79ddfb2127d6	\N
1905077	\N	67	f	4e6e99b1-8a42-46bb-b423-7d0225702a58	\N
1905077	\N	67	f	22dedf21-7fab-42a9-9b2a-af61a11af49d	\N
1905077	\N	67	f	c684a6e7-2ccf-42cc-b580-180e36613cde	\N
1905077	\N	67	f	611eb135-acad-40e9-b9c7-e8d3e37d9d0d	\N
1905077	\N	67	f	1b20e484-3330-41df-8e2f-7b23ddcfe75d	\N
1905077	\N	67	f	6659b8f3-72af-46aa-bfea-4317a1238c3f	\N
1905077	\N	67	f	cbb06644-f700-49ca-89df-4873e4c18bd8	\N
1905077	\N	67	f	cce2238a-6b82-4bfc-8524-7df1b9690eab	\N
1905077	\N	67	f	36d01c04-7f0d-4160-aa77-7af8859cf964	\N
1905077	\N	67	f	e6f257b8-9520-40e2-a7df-4b98137b58d4	\N
1905077	\N	67	f	5bcd62a0-91c5-4216-938b-76068998dca6	\N
1905077	\N	67	f	c136adbc-10e3-4c28-8fca-55b260f403ee	\N
1905077	\N	67	f	299fe9de-7cb3-4147-a47f-a60f51c3c459	\N
1905077	\N	67	f	61ce2d45-5d7d-4e9e-bdb6-2fb26990167b	\N
1905077	\N	67	f	a4984336-176f-46ac-aa7a-77badc1678f8	\N
1905077	\N	67	f	018a9970-a61c-4dbc-91d5-793214f78359	\N
1905077	\N	67	f	1ccca37b-f7dc-4e0e-b155-7519c0a13c6d	\N
1905077	\N	67	f	2efa5159-3fe7-434c-83d9-e79fd2e18f10	\N
1905077	\N	67	f	c55792f0-4906-404b-b1e7-dbb7eb8ef58e	\N
1905077	\N	67	f	d22f673d-53d5-47c1-a900-d3e8b5b03bf7	\N
1905077	\N	67	f	ec021951-ed2c-428c-80c6-02bf5f5afbc6	\N
1905077	\N	67	f	bf0f4b44-f256-4dde-b401-d564d97fe890	\N
1905077	\N	67	f	f1c8b730-abc8-4cd7-be48-199a4c657b50	\N
1905077	\N	67	f	c113436f-dde6-4c29-b122-25e25aa9a05f	\N
1905077	\N	67	f	a401a8bb-0652-44b6-b9c2-2eea27c82c6f	\N
1905077	\N	67	f	0b279794-b406-4905-af30-8eaa608737c8	\N
1905077	\N	67	f	9eaf8933-8b42-4cf5-8ff3-e164734f335f	\N
1905077	\N	67	f	d64e771e-e6a3-4c10-84e6-c7f1a1c362a5	\N
1905077	\N	67	f	e3ad1fc5-811e-4ce6-9b94-24a447de7d79	\N
1905077	\N	67	f	cbaf6428-25c5-4d13-8861-3de3283213de	\N
1905077	\N	67	f	1afbea42-b50a-44d9-81c4-8a0ae82f9875	\N
1905077	\N	67	f	516941b4-d176-45c3-add8-e819f6a759ae	\N
1905077	\N	67	f	197b5071-80e2-4c2c-85b9-ed47c249fa8e	\N
1905077	\N	67	f	5bbbd438-557b-48eb-9b50-6e0298263422	\N
1905077	\N	67	f	ace6678d-ddc8-43ea-9356-5311209cb4a3	\N
1905077	\N	67	f	fe8a21c1-e914-465f-9a04-a465b0a670d4	\N
1905077	\N	67	f	fe8c00e8-2eeb-4924-ae53-345ebe992ab1	\N
1905077	\N	67	f	4b4bbdf4-880c-4f4d-aafb-b07bbbe01be6	\N
1905077	\N	67	f	e04d31f8-78a8-4aa6-9620-99be71901d1d	\N
1905077	\N	67	f	0f5b7d66-6dbe-47d2-9003-6ee005fc8aca	\N
1905077	\N	67	f	85e76669-388a-4730-b339-db1d4e939b33	\N
1905077	\N	67	f	3398ccfe-2127-4da7-9266-429206bfdb17	\N
1905077	\N	67	f	27ab80ca-87ba-4527-87d3-741c6ec56468	\N
1905077	\N	67	f	fca1a34a-892d-4252-88c7-77dec69feb79	\N
1905077	\N	67	f	f476c9e9-e8e0-4825-be2c-71df72d0eecf	\N
1905077	\N	67	f	feedfd87-4c3c-44a2-8fcf-3c219a2eedd5	\N
1905077	\N	67	f	e5fd8f49-5b73-425a-ae82-8dc44471e1d9	\N
1905077	\N	67	f	ba071317-595b-4bf2-ac8c-4a197c9f8010	\N
1905077	\N	67	f	4c03fc22-988f-4394-8822-01a781ce601e	\N
1905077	\N	67	f	f05ce38e-40b5-458c-a789-1813c7fa0f05	\N
1905077	\N	67	f	b6907377-0dc7-44fd-bc7c-ed29d5b3c66b	\N
1905077	\N	67	f	dfcb3fee-e24a-448b-942c-2b4d68bd1d19	\N
1905077	\N	67	f	c9020d18-751b-4ba6-bdb1-f080a7a1cc30	\N
1905077	\N	67	f	ce3370d3-4f4e-4772-bbc8-2e375dee01d8	\N
1905077	\N	67	f	559cda65-7933-491f-8831-2189a4d68264	\N
1905077	\N	67	f	5860eb22-c462-4395-9f93-c5abda1b9c7b	\N
1905077	\N	67	f	9bead093-e45c-4e2a-a3c2-a1f597f8b978	\N
1905077	\N	67	f	d279823a-e337-4044-acbd-a4bd36d16dca	\N
1905077	\N	67	f	f2410d77-b26b-496d-845e-a8f1bd9ebc7b	\N
1905077	\N	67	f	ce79a70b-de56-43c8-84d4-1f6e48dd0aa8	\N
1905077	\N	67	f	83586fcf-91e1-4a0f-a3bc-01b03340ac1a	\N
1905077	\N	67	f	0dae3fc3-f2dc-4a8c-863e-fc6b11a5cc50	\N
1905077	\N	67	f	414bcc7d-f9b0-4116-8cf5-0ffc34376499	\N
1905077	\N	67	f	4efd8795-a492-4c83-8421-5626b0672381	\N
1905077	\N	67	f	fbe5bb3f-3ae4-44bf-9b35-5d9003512dc9	\N
1905077	\N	67	f	a0f7ba4b-216c-4fe9-853b-adb2966715b9	\N
1905077	\N	67	f	3cabb4ea-a4e0-4929-92d0-7e960ee1b6df	\N
1905077	\N	67	f	d4dbd59f-25f1-49bd-a4fb-f951bf749624	\N
1905077	\N	67	f	f0235da8-593e-4165-94e6-d9d207946a65	\N
1905077	\N	67	f	c0d48ed1-72f6-45dc-916e-64dc54c43ec8	\N
1905077	\N	67	f	871ce747-dd9f-4271-a787-da59c0b363d8	\N
1905077	\N	67	f	c75f823a-6f95-45c5-ae4b-46745d728569	\N
1905077	\N	67	f	4fa9e996-8f69-4009-adba-738d7db7e460	\N
1905077	\N	67	f	a99f5f50-d2a0-4452-b2f6-7b3c1a4151cf	\N
1905077	\N	67	f	569103c4-de7d-4979-9daf-5d7ab8ec522b	\N
1905077	\N	67	f	84eebab3-599d-429c-b3b2-2f77902bfdde	\N
1905077	\N	67	f	4b36fbf3-814c-4175-ad7c-78a503e8ee9c	\N
1905077	\N	67	f	2593296d-c9b5-4830-bc44-c975df99d63e	\N
1905077	\N	67	f	99223f47-c400-4a7d-b065-826499c5c2df	\N
1905077	\N	67	f	529a9027-96f2-470c-a2b4-5db43fb3f1d7	\N
1905077	\N	67	f	d470c8da-544b-41d0-ab78-cf439d273e49	\N
1905077	\N	67	f	4900ff7c-372e-4ef2-b89c-159dd39574c6	\N
1905077	\N	67	f	2cb6e6ae-b8fa-4eab-bf22-25c057a2717e	\N
1905077	\N	67	f	208e8a61-da26-400d-90f1-be53f37af78b	\N
1905077	\N	67	f	bc0eec36-0f1f-4e0f-b4c8-975026dddcf9	\N
1905077	\N	67	f	8c1f761d-84ee-4bc6-bd86-bf2c77d0bb25	\N
1905077	\N	67	f	77b5f702-69b9-482e-ab5a-67270e7e2fad	\N
1905077	\N	67	f	0a88b263-c9a0-4161-af30-32b2a05091e4	\N
1905077	\N	67	f	e48d0895-a512-4527-8354-9645ad75ccf5	\N
1905077	\N	67	f	4b00bb71-c43b-4992-9728-acab7abbc51b	\N
1905077	\N	67	f	ce6e89d7-c35c-475c-9248-4ea9de5e2245	\N
1905077	\N	67	f	8557cc54-5dd3-4f0f-8f86-c14b37e16682	\N
1905077	\N	67	f	1049d5b4-a1d0-482a-b551-a6fe5ba7c8cf	\N
1905077	\N	67	f	351fad02-9f20-4224-9f25-438f515f144a	\N
1905077	\N	67	f	c1056d36-f406-4c64-9bdd-7b77dcb97963	\N
1905077	\N	67	f	777a17c0-5194-4e18-a9e7-be4a9522ed4e	\N
1905084	2161	51	t	03d51151-8525-403e-8651-b46bb95ba394	\N
\.


--
-- Data for Name: trip; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trip (id, start_timestamp, route, time_type, time_list, travel_direction, bus, is_default, driver, approved_by, end_timestamp, start_location, end_location, path, is_live, passenger_count, helper, valid) FROM stdin;
1958	2024-01-31 01:34:00.489636+06	5	afternoon	{"(36,\\"2024-02-01 19:40:00+06\\")","(37,\\"2024-02-01 19:50:00+06\\")","(38,\\"2024-02-01 19:55:00+06\\")","(39,\\"2024-02-01 20:00:00+06\\")","(40,\\"2024-02-01 20:07:00+06\\")","(70,\\"2024-02-01 20:10:00+06\\")"}	from_buet	Ba-22-4326	t	rafiqul	nazmul	2024-01-31 01:58:43.640821+06	(23.76237,90.35889)	(23.7278344,90.3910436)	{"(23.7623489,90.358887)","(23.7663533,90.3648367)","(23.7655104,90.3651403)","(23.7646664,90.3654348)","(23.7641944,90.3652159)","(23.7640314,90.3646332)","(23.7638582,90.3640017)","(23.763682,90.3633785)","(23.7635197,90.3628186)","(23.76334,90.3622083)","(23.7631566,90.3616031)","(23.7629762,90.3609855)","(23.7628117,90.3603567)","(23.7626414,90.3597687)","(23.7624553,90.3591464)","(23.7620753,90.3588786)","(23.7615786,90.3589119)","(23.7610516,90.3589305)","(23.7605511,90.3588835)","(23.7600263,90.3589248)","(23.7595375,90.3590761)","(23.7590781,90.3592982)","(23.7586213,90.3595548)","(23.7581814,90.3598812)","(23.7577712,90.3602328)","(23.7574001,90.3606268)","(23.7571153,90.3610577)","(23.7567658,90.3618999)","(23.7562055,90.3625783)","(23.7556434,90.3632366)","(23.75512,90.3638618)","(23.75458,90.3645316)","(23.7540433,90.3651785)","(23.75352,90.3657835)","(23.7529799,90.3664234)","(23.7524978,90.3669876)","(23.7517913,90.3676036)","(23.7511659,90.3680588)","(23.7504509,90.3685497)","(23.7497367,90.3690418)","(23.7490434,90.369525)","(23.74837,90.3699901)","(23.7477591,90.3704005)","(23.7470341,90.3708881)","(23.7463433,90.37136)","(23.7456102,90.3718518)","(23.7449232,90.3723101)","(23.7442483,90.3727416)","(23.7436292,90.3731604)","(23.7429011,90.3736597)","(23.7422153,90.3740487)","(23.7414977,90.3744266)","(23.7407603,90.3748002)","(23.7400468,90.3751518)","(23.7393131,90.3755332)","(23.7385949,90.3759168)","(23.7385433,90.3758267)","(23.7390717,90.3755345)","(23.7395864,90.3752647)","(23.7387134,90.3758541)","(23.7385722,90.3778198)","(23.7388566,90.3795551)","(23.7396279,90.3807628)","(23.7403133,90.3815189)","(23.7406496,90.3831105)","(23.739228,90.3833956)","(23.7379529,90.3837217)","(23.7367137,90.3839936)","(23.7354392,90.3842999)","(23.7341904,90.38461)","(23.7327824,90.3849899)","(23.7325079,90.386185)","(23.7322001,90.387033)","(23.73019,90.3873201)","(23.7286641,90.3883909)","(23.7279262,90.3891317)","(23.7272991,90.389751)","(37.4226711,-122.0849872)","(23.72723,90.38992)","(23.7276533,90.390254)","(23.727735,90.3907998)"}	f	0	reyazul	t
1004	2024-01-27 23:28:31.997913+06	3	evening	{"(17,\\"2024-02-14 23:30:00+06\\")","(18,\\"2024-02-14 23:45:00+06\\")","(19,\\"2024-02-14 23:48:00+06\\")","(20,\\"2024-02-14 23:50:00+06\\")","(21,\\"2024-02-14 23:52:00+06\\")","(22,\\"2024-02-14 23:54:00+06\\")","(23,\\"2024-02-14 23:56:00+06\\")","(24,\\"2024-02-14 23:58:00+06\\")","(25,\\"2024-02-14 00:00:00+06\\")","(26,\\"2024-02-14 00:02:00+06\\")","(70,\\"2024-02-14 00:04:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-27 23:30:27.272595+06	\N	\N	\N	f	0	rashid56	t
1038	2024-01-27 23:33:34.268594+06	7	morning	{"(50,\\"2024-02-04 12:40:00+06\\")","(51,\\"2024-02-04 12:42:00+06\\")","(52,\\"2024-02-04 12:43:00+06\\")","(53,\\"2024-02-04 12:46:00+06\\")","(54,\\"2024-02-04 12:47:00+06\\")","(55,\\"2024-02-04 12:48:00+06\\")","(56,\\"2024-02-04 12:50:00+06\\")","(57,\\"2024-02-04 12:52:00+06\\")","(58,\\"2024-02-04 12:53:00+06\\")","(59,\\"2024-02-04 12:54:00+06\\")","(60,\\"2024-02-04 12:56:00+06\\")","(61,\\"2024-02-04 12:58:00+06\\")","(62,\\"2024-02-04 13:00:00+06\\")","(63,\\"2024-02-04 13:02:00+06\\")","(70,\\"2024-02-04 13:00:00+06\\")"}	to_buet	Ba-35-1461	t	sohel55	nazmul	2024-01-27 23:33:45.29544+06	\N	\N	\N	f	0	rashid56	t
1039	2024-01-27 23:36:13.687176+06	7	afternoon	{"(50,\\"2024-02-04 19:40:00+06\\")","(51,\\"2024-02-04 19:48:00+06\\")","(52,\\"2024-02-04 19:50:00+06\\")","(53,\\"2024-02-04 19:52:00+06\\")","(54,\\"2024-02-04 19:54:00+06\\")","(55,\\"2024-02-04 19:56:00+06\\")","(56,\\"2024-02-04 19:58:00+06\\")","(57,\\"2024-02-04 20:00:00+06\\")","(58,\\"2024-02-04 20:02:00+06\\")","(59,\\"2024-02-04 20:04:00+06\\")","(60,\\"2024-02-04 20:06:00+06\\")","(61,\\"2024-02-04 20:08:00+06\\")","(62,\\"2024-02-04 20:10:00+06\\")","(63,\\"2024-02-04 20:12:00+06\\")","(70,\\"2024-02-04 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	sohel55	nazmul	2024-01-27 23:36:26.395124+06	\N	\N	\N	f	0	rashid56	t
1040	2024-01-27 23:43:56.679781+06	7	evening	{"(50,\\"2024-02-04 23:30:00+06\\")","(51,\\"2024-02-04 23:38:00+06\\")","(52,\\"2024-02-04 23:40:00+06\\")","(53,\\"2024-02-04 23:42:00+06\\")","(54,\\"2024-02-04 23:44:00+06\\")","(55,\\"2024-02-04 23:46:00+06\\")","(56,\\"2024-02-04 23:48:00+06\\")","(57,\\"2024-02-04 23:50:00+06\\")","(58,\\"2024-02-04 23:52:00+06\\")","(59,\\"2024-02-04 23:54:00+06\\")","(60,\\"2024-02-04 23:56:00+06\\")","(61,\\"2024-02-04 23:58:00+06\\")","(62,\\"2024-02-04 00:00:00+06\\")","(63,\\"2024-02-04 00:02:00+06\\")","(70,\\"2024-02-04 00:04:00+06\\")"}	from_buet	Ba-35-1461	t	sohel55	nazmul	2024-01-27 23:48:50.815707+06	\N	\N	\N	f	0	rashid56	t
1098	2024-01-28 00:18:54.862311+06	3	morning	{"(17,\\"2024-02-17 12:40:00+06\\")","(18,\\"2024-02-17 12:42:00+06\\")","(19,\\"2024-02-17 12:44:00+06\\")","(20,\\"2024-02-17 12:46:00+06\\")","(21,\\"2024-02-17 12:48:00+06\\")","(22,\\"2024-02-17 12:50:00+06\\")","(23,\\"2024-02-17 12:52:00+06\\")","(24,\\"2024-02-17 12:54:00+06\\")","(25,\\"2024-02-17 12:57:00+06\\")","(26,\\"2024-02-17 13:00:00+06\\")","(70,\\"2024-02-17 13:15:00+06\\")"}	to_buet	Ba-35-1461	t	altaf	nazmul	2024-01-28 00:23:03.782982+06	\N	\N	\N	f	0	rashid56	t
1099	2024-01-28 00:24:57.065157+06	3	afternoon	{"(17,\\"2024-02-17 19:40:00+06\\")","(18,\\"2024-02-17 19:55:00+06\\")","(19,\\"2024-02-17 19:58:00+06\\")","(20,\\"2024-02-17 20:00:00+06\\")","(21,\\"2024-02-17 20:02:00+06\\")","(22,\\"2024-02-17 20:04:00+06\\")","(23,\\"2024-02-17 20:06:00+06\\")","(24,\\"2024-02-17 20:08:00+06\\")","(25,\\"2024-02-17 20:10:00+06\\")","(26,\\"2024-02-17 20:12:00+06\\")","(70,\\"2024-02-17 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	altaf	nazmul	2024-01-28 00:30:26.241063+06	\N	\N	\N	f	0	rashid56	t
2197	2024-02-09 10:17:39.988862+06	5	morning	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:17:44.951+06\\")"}	to_buet	Ba-98-5568	t	ibrahim	nazmul	2024-02-09 10:24:21.196096+06	(23.7276,90.3917)	(23.7275682,90.3917004)	{"(23.7275743,90.3917007)"}	f	0	khairul	t
1941	2024-01-30 18:51:48.390011+06	7	evening	{"(50,\\"2024-01-30 23:30:00+06\\")","(51,\\"2024-01-30 23:38:00+06\\")","(52,\\"2024-01-30 23:40:00+06\\")","(53,\\"2024-01-30 23:42:00+06\\")","(54,\\"2024-01-30 23:44:00+06\\")","(55,\\"2024-01-30 23:46:00+06\\")","(56,\\"2024-01-30 23:48:00+06\\")","(57,\\"2024-01-30 23:50:00+06\\")","(58,\\"2024-01-30 23:52:00+06\\")","(59,\\"2024-01-30 23:54:00+06\\")","(60,\\"2024-01-30 23:56:00+06\\")","(61,\\"2024-01-30 23:58:00+06\\")","(62,\\"2024-01-30 00:00:00+06\\")","(63,\\"2024-01-30 00:02:00+06\\")","(70,\\"2024-01-30 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	sohel55	\N	2024-01-30 18:55:06.87056+06	(23.7664933,90.3647317)	(23.7664737,90.3647329)	{"(23.7664569,90.3647362)"}	f	0	nasir81	t
1990	2024-01-30 18:59:28.377695+06	1	morning	{"(1,\\"2024-02-05 12:15:00+06\\")","(2,\\"2024-02-05 12:18:00+06\\")","(3,\\"2024-02-05 12:20:00+06\\")","(4,\\"2024-02-05 12:23:00+06\\")","(5,\\"2024-02-05 12:26:00+06\\")","(6,\\"2024-02-05 12:29:00+06\\")","(7,\\"2024-02-05 12:49:00+06\\")","(8,\\"2024-02-05 12:51:00+06\\")","(9,\\"2024-02-05 12:53:00+06\\")","(10,\\"2024-02-05 12:55:00+06\\")","(11,\\"2024-02-05 12:58:00+06\\")","(70,\\"2024-02-05 13:05:00+06\\")"}	to_buet	Ba-19-0569	t	altaf	nazmul	2024-01-30 19:02:06.40486+06	(23.7664933,90.3647317)	(23.7664716,90.3647332)	{"(23.7664933,90.3647317)"}	f	0	siddiq2	t
2198	2024-02-09 10:24:34.991175+06	5	afternoon	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:24:39.958+06\\")"}	from_buet	Ba-98-5568	t	ibrahim	nazmul	2024-02-09 10:26:15.403943+06	(23.7276,90.3917)	(23.7275686,90.3917004)	{"(23.7275743,90.3917007)"}	f	0	khairul	t
1155	2024-01-28 02:27:41.406627+06	6	morning	{"(41,\\"2024-01-29 12:40:00+06\\")","(42,\\"2024-01-29 12:42:00+06\\")","(43,\\"2024-01-29 12:45:00+06\\")","(44,\\"2024-01-29 12:47:00+06\\")","(45,\\"2024-01-29 12:49:00+06\\")","(46,\\"2024-01-29 12:51:00+06\\")","(47,\\"2024-01-29 12:52:00+06\\")","(48,\\"2024-01-29 12:53:00+06\\")","(49,\\"2024-01-29 12:54:00+06\\")","(70,\\"2024-01-29 13:10:00+06\\")"}	to_buet	Ba-17-2081	t	altaf	nazmul	2024-01-28 02:28:25.45167+06	\N	\N	{"(23.7646853,90.3621754)","(23.7647807,90.3633323)","(23.7638179,90.3638189)"}	f	0	rashid56	t
1156	2024-01-28 02:40:01.793866+06	6	afternoon	{"(41,\\"2024-01-29 19:40:00+06\\")","(42,\\"2024-01-29 19:56:00+06\\")","(43,\\"2024-01-29 19:58:00+06\\")","(44,\\"2024-01-29 20:00:00+06\\")","(45,\\"2024-01-29 20:02:00+06\\")","(46,\\"2024-01-29 20:04:00+06\\")","(47,\\"2024-01-29 20:06:00+06\\")","(48,\\"2024-01-29 20:08:00+06\\")","(49,\\"2024-01-29 20:10:00+06\\")","(70,\\"2024-01-29 20:12:00+06\\")"}	from_buet	Ba-17-2081	t	altaf	nazmul	2024-01-28 02:41:04.128471+06	\N	\N	{"(23.764785,90.362795)","(23.764785,90.362795)","(23.7641433,90.3635413)","(23.7641433,90.3635413)","(23.7629328,90.3644588)","(23.7629328,90.3644588)","(23.7619764,90.3647657)","(23.7619764,90.3647657)"}	f	0	rashid56	t
1140	2024-01-28 03:05:49.773112+06	8	morning	{"(64,\\"2024-01-28 12:10:00+06\\")","(65,\\"2024-01-28 12:13:00+06\\")","(66,\\"2024-01-28 12:18:00+06\\")","(67,\\"2024-01-28 12:20:00+06\\")","(68,\\"2024-01-28 12:22:00+06\\")","(69,\\"2024-01-28 12:25:00+06\\")","(70,\\"2024-01-28 12:40:00+06\\")"}	to_buet	Ba-83-8014	t	ibrahim	nazmul	2024-01-28 03:06:57.62416+06	(23.762675,90.3645433)	(23.7610135,90.3651185)	{"(23.7626585,90.364548)","(23.7649167,90.363245)","(23.7639681,90.3636351)","(23.7626791,90.3645418)","(23.7617005,90.3648539)"}	f	0	mahbub777	t
1203	2024-01-28 03:35:02.834051+06	6	morning	{"(41,\\"2024-02-01 12:40:00+06\\")","(42,\\"2024-02-01 12:42:00+06\\")","(43,\\"2024-02-01 12:45:00+06\\")","(44,\\"2024-02-01 12:47:00+06\\")","(45,\\"2024-02-01 12:49:00+06\\")","(46,\\"2024-02-01 12:51:00+06\\")","(47,\\"2024-02-01 12:52:00+06\\")","(48,\\"2024-02-01 12:53:00+06\\")","(49,\\"2024-02-01 12:54:00+06\\")","(70,\\"2024-02-01 13:10:00+06\\")"}	to_buet	Ba-48-5757	t	ibrahim	nazmul	2024-01-28 03:35:45.077402+06	(23.76481,90.36288)	(23.7623159,90.3646402)	{"(23.7648229,90.3629289)","(23.763818,90.3638189)","(23.7624585,90.3646186)"}	f	0	rashid56	t
1141	2024-01-28 03:18:47.160923+06	8	afternoon	{"(64,\\"2024-01-28 19:40:00+06\\")","(65,\\"2024-01-28 19:55:00+06\\")","(66,\\"2024-01-28 19:58:00+06\\")","(67,\\"2024-01-28 20:01:00+06\\")","(68,\\"2024-01-28 20:04:00+06\\")","(69,\\"2024-01-28 20:07:00+06\\")","(70,\\"2024-01-28 20:10:00+06\\")"}	from_buet	Ba-83-8014	t	ibrahim	nazmul	2024-01-28 03:19:30.927914+06	(23.7607998,90.3651584)	(23.7632479,90.3643324)	{"(23.7608562,90.3651593)","(23.7646898,90.3623264)","(23.7647391,90.3633399)","(23.7637288,90.3636801)"}	f	0	mahbub777	t
1142	2024-01-28 03:30:32.69161+06	8	evening	{"(64,\\"2024-01-28 23:30:00+06\\")","(65,\\"2024-01-28 23:45:00+06\\")","(66,\\"2024-01-28 23:48:00+06\\")","(67,\\"2024-01-28 23:51:00+06\\")","(68,\\"2024-01-28 23:54:00+06\\")","(69,\\"2024-01-28 23:57:00+06\\")","(70,\\"2024-01-28 00:00:00+06\\")"}	from_buet	Ba-83-8014	t	ibrahim	nazmul	2024-01-28 03:31:40.217163+06	(23.7630383,90.364425)	(23.7615237,90.3649582)	{"(23.7630204,90.3644298)","(23.76468,90.36243)","(23.7645307,90.3634049)","(23.7638345,90.3641268)","(23.7623752,90.3646502)"}	f	0	mahbub777	t
1157	2024-01-28 02:49:23.596861+06	6	evening	{"(41,\\"2024-01-29 23:30:00+06\\")","(42,\\"2024-01-29 23:46:00+06\\")","(43,\\"2024-01-29 23:48:00+06\\")","(44,\\"2024-01-29 23:50:00+06\\")","(45,\\"2024-01-29 23:52:00+06\\")","(46,\\"2024-01-29 23:54:00+06\\")","(47,\\"2024-01-29 23:56:00+06\\")","(48,\\"2024-01-29 23:58:00+06\\")","(49,\\"2024-01-29 00:00:00+06\\")","(70,\\"2024-01-29 00:02:00+06\\")"}	from_buet	Ba-17-2081	t	altaf	nazmul	2024-01-28 02:50:10.720968+06	\N	(23.7383,90.44334)	{"(23.764715,90.3625517)","(23.764715,90.3625517)","(23.764715,90.3625517)","(23.7638773,90.3640616)","(23.7638773,90.3640616)","(23.7638773,90.3640616)","(23.7630047,90.3644121)","(23.7630047,90.3644121)","(23.7630047,90.3644121)"}	f	0	rashid56	t
1162	2024-01-28 03:52:19.424902+06	1	afternoon	{"(1,\\"2024-01-29 19:40:00+06\\")","(2,\\"2024-01-29 19:47:00+06\\")","(3,\\"2024-01-29 19:50:00+06\\")","(4,\\"2024-01-29 19:52:00+06\\")","(5,\\"2024-01-29 19:54:00+06\\")","(6,\\"2024-01-29 20:06:00+06\\")","(7,\\"2024-01-29 20:09:00+06\\")","(8,\\"2024-01-29 20:12:00+06\\")","(9,\\"2024-01-29 20:15:00+06\\")","(10,\\"2024-01-29 20:18:00+06\\")","(11,\\"2024-01-29 20:21:00+06\\")","(70,\\"2024-01-29 20:24:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	2024-01-28 04:24:11.687318+06	(23.75632,90.3641017)	(23.7275826,90.3917008)	{"(23.75632,90.3641017)","(23.7552009,90.3641389)","(23.7544482,90.3647013)","(23.7536596,90.3656218)","(23.7528312,90.3666003)","(23.7519332,90.3674972)","(23.7511598,90.3680533)","(23.7502049,90.3687171)","(23.7491714,90.3694372)","(23.7483965,90.3699624)","(23.7474082,90.3706356)","(23.7463798,90.3713339)","(23.7455886,90.3718562)","(23.7446149,90.3725005)","(23.7438287,90.3730144)","(23.7428648,90.3736806)","(23.7420425,90.374115)","(23.7410082,90.3746741)","(23.7401806,90.3750763)","(23.7391616,90.3756091)","(23.7384099,90.3765045)","(23.7385368,90.3775494)","(23.7387081,90.3788031)","(23.7388976,90.3797904)","(23.7392359,90.380841)","(23.7401354,90.3806777)","(23.740358,90.3818204)","(23.7405714,90.3829354)","(23.7395909,90.3833197)","(23.7386776,90.3835081)","(23.7377446,90.3837713)","(23.736841,90.3839697)","(23.7359126,90.3841714)","(23.7350143,90.384413)","(23.7340661,90.3846397)","(23.7331694,90.3848863)","(23.7324898,90.385719)","(23.7325996,90.3867607)","(23.7314599,90.386967)","(23.7304914,90.3872093)","(23.7296013,90.387629)","(23.7287833,90.3882836)","(23.7280026,90.3890557)","(23.7273257,90.3897197)","(23.7277163,90.3907071)","(23.7280587,90.3916682)"}	f	0	farid99	t
1163	2024-01-28 04:24:47.12721+06	1	evening	{"(1,\\"2024-01-29 23:30:00+06\\")","(2,\\"2024-01-29 23:37:00+06\\")","(3,\\"2024-01-29 23:40:00+06\\")","(4,\\"2024-01-29 23:42:00+06\\")","(5,\\"2024-01-29 23:44:00+06\\")","(6,\\"2024-01-29 23:56:00+06\\")","(7,\\"2024-01-29 23:59:00+06\\")","(8,\\"2024-01-29 00:02:00+06\\")","(9,\\"2024-01-29 00:05:00+06\\")","(10,\\"2024-01-29 00:08:00+06\\")","(11,\\"2024-01-29 00:11:00+06\\")","(70,\\"2024-01-29 00:14:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	2024-01-28 04:38:22.901212+06	(23.7276,90.3917)	(23.74363,90.37316)	{"(23.7276,90.3917)","(23.7647037,90.3622592)","(23.7648629,90.3633074)","(23.7638522,90.3639699)","(23.7629304,90.3644598)","(23.762062,90.3647632)","(23.7611915,90.3650536)","(23.7601869,90.3654399)","(23.7593104,90.3657095)","(23.758807,90.3645671)","(23.7582435,90.3634954)","(23.7571685,90.3638249)","(23.7560853,90.3641782)","(23.7550852,90.3640086)","(23.7542803,90.3649014)","(23.7534304,90.3658863)","(23.7525971,90.3668714)","(23.7516004,90.367748)","(23.7505598,90.3684734)","(23.7495101,90.3691982)","(23.7484634,90.3699249)","(23.7474068,90.3706366)","(23.7463784,90.3713349)","(23.7453051,90.3720566)","(23.744265,90.3727299)"}	f	0	farid99	t
1179	2024-01-28 04:39:14.082505+06	6	morning	{"(41,\\"2024-01-30 12:40:00+06\\")","(42,\\"2024-01-30 12:42:00+06\\")","(43,\\"2024-01-30 12:45:00+06\\")","(44,\\"2024-01-30 12:47:00+06\\")","(45,\\"2024-01-30 12:49:00+06\\")","(46,\\"2024-01-30 12:51:00+06\\")","(47,\\"2024-01-30 12:52:00+06\\")","(48,\\"2024-01-30 12:53:00+06\\")","(49,\\"2024-01-30 12:54:00+06\\")","(70,\\"2024-01-30 13:10:00+06\\")"}	to_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-28 04:41:34.665157+06	(23.743595,90.3731833)	(23.7594097,90.3656727)	{"(23.743595,90.3731833)","(23.7645149,90.3634097)","(23.7635965,90.3642248)","(23.7626683,90.3645331)","(23.7615213,90.3649592)","(23.760607,90.3652536)","(23.7597444,90.3655642)"}	f	0	khairul	t
1180	2024-01-28 04:43:25.349017+06	6	afternoon	{"(41,\\"2024-01-30 19:40:00+06\\")","(42,\\"2024-01-30 19:56:00+06\\")","(43,\\"2024-01-30 19:58:00+06\\")","(44,\\"2024-01-30 20:00:00+06\\")","(45,\\"2024-01-30 20:02:00+06\\")","(46,\\"2024-01-30 20:04:00+06\\")","(47,\\"2024-01-30 20:06:00+06\\")","(48,\\"2024-01-30 20:08:00+06\\")","(49,\\"2024-01-30 20:10:00+06\\")","(70,\\"2024-01-30 20:12:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-28 05:07:47.276301+06	(23.76293,90.36446)	(23.7275691,90.3917004)	{"(23.7629215,90.3644627)","(23.761893,90.3648211)","(23.760958,90.3651252)","(23.7598395,90.3655478)","(23.7590257,90.3650313)","(23.7583038,90.3636066)","(23.757252,90.3637957)","(23.7561769,90.364146)","(23.7551482,90.3640747)","(23.7540848,90.3651296)","(23.7529648,90.3664414)","(23.7517438,90.3676471)","(23.7503818,90.3685942)","(23.7490333,90.3695325)","(23.7482115,90.370075)","(23.7469167,90.3709675)","(23.7460972,90.3714986)","(23.7448431,90.372356)","(23.7440218,90.3728745)","(23.7426887,90.3737957)","(23.7418545,90.3741857)","(23.7404619,90.374948)","(23.7396228,90.3753398)","(23.7384031,90.376188)","(23.7384991,90.3771824)","(23.7386299,90.3782604)","(23.738924,90.3798963)","(23.739104,90.380962)","(23.7401694,90.3808655)","(23.740456,90.3823275)","(23.7399628,90.3832297)","(23.7388421,90.3834792)","(23.7376836,90.3837859)","(23.7364057,90.3840543)","(23.7352299,90.3843543)","(23.7339625,90.3846692)","(23.7327725,90.3850195)","(23.7325149,90.3861182)","(23.7320907,90.387031)","(23.7303474,90.3872618)","(23.7294433,90.3877279)","(23.7286687,90.3883896)","(23.7279292,90.3891291)","(23.727264,90.3898125)","(23.7279039,90.3912376)"}	f	0	khairul	t
1181	2024-01-28 05:14:11.476372+06	6	evening	{"(41,\\"2024-01-30 23:30:00+06\\")","(42,\\"2024-01-30 23:46:00+06\\")","(43,\\"2024-01-30 23:48:00+06\\")","(44,\\"2024-01-30 23:50:00+06\\")","(45,\\"2024-01-30 23:52:00+06\\")","(46,\\"2024-01-30 23:54:00+06\\")","(47,\\"2024-01-30 23:56:00+06\\")","(48,\\"2024-01-30 23:58:00+06\\")","(49,\\"2024-01-30 00:00:00+06\\")","(70,\\"2024-01-30 00:02:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-28 05:24:01.704883+06	(23.7605667,90.3652883)	(23.7335124,90.3847891)	{"(23.760503,90.3653183)","(23.7594967,90.3656476)","(23.7587519,90.3644617)","(23.7578897,90.3635623)","(23.7568074,90.3639391)","(23.7557618,90.364289)","(23.7547689,90.3642993)","(23.7541415,90.3650692)","(23.7530767,90.3663061)","(23.7519004,90.3675201)","(23.7511399,90.368056)","(23.7498637,90.368954)","(23.7490843,90.3694787)","(23.7477634,90.3703976)","(23.7469662,90.370914)","(23.74566,90.3718175)","(23.7442341,90.3727505)","(23.7428323,90.3737021)","(23.7414635,90.3744477)","(23.7405702,90.3748659)","(23.7392135,90.3755876)","(23.7384338,90.3760968)","(23.7384761,90.3771184)","(23.7386995,90.3787562)","(23.7388878,90.379826)","(23.739499,90.3807819)","(23.7402677,90.3813673)","(23.740556,90.3828572)","(23.7396403,90.3833063)","(23.7384407,90.3835694)","(23.7371857,90.3838975)","(23.7359756,90.3841543)","(23.7347394,90.3844857)","(23.7335124,90.3847891)"}	f	0	khairul	t
2199	2024-02-09 10:26:26.98145+06	5	evening	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:26:31.997+06\\")"}	from_buet	Ba-98-5568	t	ibrahim	nazmul	2024-02-09 10:28:11.929196+06	(23.7275684,90.3917004)	(23.7275686,90.3917004)	{"(23.7275675,90.3917007)"}	f	0	khairul	t
1991	2024-01-30 19:02:09.106701+06	1	afternoon	{"(1,\\"2024-02-05 19:40:00+06\\")","(2,\\"2024-02-05 19:47:00+06\\")","(3,\\"2024-02-05 19:50:00+06\\")","(4,\\"2024-02-05 19:52:00+06\\")","(5,\\"2024-02-05 19:54:00+06\\")","(6,\\"2024-02-05 20:06:00+06\\")","(7,\\"2024-02-05 20:09:00+06\\")","(8,\\"2024-02-05 20:12:00+06\\")","(9,\\"2024-02-05 20:15:00+06\\")","(10,\\"2024-02-05 20:18:00+06\\")","(11,\\"2024-02-05 20:21:00+06\\")","(70,\\"2024-02-05 20:24:00+06\\")"}	from_buet	Ba-19-0569	t	altaf	nazmul	2024-01-30 19:09:06.146212+06	(23.7664716,90.3647332)	(23.7664916,90.3647319)	{"(23.7664933,90.3647317)"}	f	0	siddiq2	t
1133	2024-01-28 11:06:01.536329+06	6	evening	{"(41,\\"2024-01-28 23:30:00+06\\")","(42,\\"2024-01-28 23:46:00+06\\")","(43,\\"2024-01-28 23:48:00+06\\")","(44,\\"2024-01-28 23:50:00+06\\")","(45,\\"2024-01-28 23:52:00+06\\")","(46,\\"2024-01-28 23:54:00+06\\")","(47,\\"2024-01-28 23:56:00+06\\")","(48,\\"2024-01-28 23:58:00+06\\")","(49,\\"2024-01-28 00:00:00+06\\")","(70,\\"2024-01-28 00:02:00+06\\")"}	from_buet	Ba-17-2081	t	arif43	nazmul	2024-01-28 11:47:17.242132+06	(23.7284663,90.385963)	(23.7626902,90.3702105)	{"(23.72896666,90.38572278)","(23.73013902,90.3858085)","(23.73133374,90.38525864)","(23.73228998,90.38525799)","(23.73345972,90.38499298)","(23.73433992,90.38448765)","(23.73529561,90.38428382)","(23.73645817,90.38395122)","(23.73757092,90.38385736)","(23.73845939,90.38358146)","(23.7393573,90.38324932)","(23.74023132,90.38297697)","(23.74118056,90.38277456)","(23.74219873,90.38249032)","(23.74327511,90.38224412)","(23.74426002,90.38203039)","(23.74584715,90.3814472)","(23.74677089,90.38103901)","(23.74814029,90.3802901)","(23.74922168,90.37977198)","(23.7506087,90.37874385)","(23.75136046,90.37812954)","(23.75348352,90.37678021)","(23.75473408,90.37604626)","(23.75551876,90.37549925)","(23.75640003,90.37514729)","(23.75728416,90.37467067)","(23.75820697,90.37434126)","(23.75890593,90.3735953)","(23.75976808,90.37309223)","(23.76136498,90.37218037)","(23.76163291,90.37113577)","(23.76246582,90.37069227)","(23.76218281,90.36974614)"}	f	0	abdulbari4	t
1456	2024-01-28 17:53:36.383554+06	2	afternoon	{"(12,\\"2024-01-29 19:40:00+06\\")","(13,\\"2024-01-29 19:52:00+06\\")","(14,\\"2024-01-29 19:54:00+06\\")","(15,\\"2024-01-29 19:57:00+06\\")","(16,\\"2024-01-29 20:00:00+06\\")","(70,\\"2024-01-29 20:03:00+06\\")"}	from_buet	Ba-19-0569	t	altaf	mashroor	2024-01-28 17:56:31.342259+06	(23.7326599,90.3851097)	(23.7279021,90.3891548)	{"(23.732575,90.3851479)","(23.7325197,90.3861528)","(23.7325197,90.3861528)","(23.7325599,90.3871496)","(23.7325599,90.3871496)","(23.7316105,90.3869601)","(23.7316105,90.3869601)","(23.7305366,90.387193)","(23.7305366,90.387193)","(23.7296208,90.3876182)","(23.7296208,90.3876182)","(23.728753,90.3883114)","(23.728753,90.3883114)","(23.7279679,90.3890902)","(23.7279679,90.3890902)"}	f	0	ASADUZZAMAN	t
1455	2024-01-28 19:18:40.65915+06	2	morning	{"(12,\\"2024-01-29 12:55:00+06\\")","(13,\\"2024-01-29 12:57:00+06\\")","(14,\\"2024-01-29 12:59:00+06\\")","(15,\\"2024-01-29 13:01:00+06\\")","(16,\\"2024-01-29 13:03:00+06\\")","(70,\\"2024-01-29 13:15:00+06\\")"}	to_buet	Ba-19-0569	t	altaf	mashroor	2024-01-28 19:21:30.530991+06	(23.7276,90.3917)	(23.8743234,90.3888165)	{"(23.7275558,90.3917032)","(23.87425,90.3848517)","(23.8742717,90.3859748)","(23.8742865,90.3871164)","(23.8743101,90.3882773)"}	f	0	ASADUZZAMAN	t
1539	2024-01-28 23:09:32.395969+06	2	evening	{"(12,\\"2024-01-29 23:30:00+06\\")","(13,\\"2024-01-29 23:42:00+06\\")","(14,\\"2024-01-29 23:45:00+06\\")","(15,\\"2024-01-29 23:48:00+06\\")","(16,\\"2024-01-29 23:51:00+06\\")","(70,\\"2024-01-29 23:54:00+06\\")"}	from_buet	Ba-69-8288	t	sohel55	\N	2024-01-28 23:11:44.565029+06	(23.7626813,90.3702191)	(23.7626943,90.3702246)	{}	f	0	mahbub777	t
1667	2024-01-29 13:25:44.736076+06	8	afternoon	{"(64,\\"2024-01-29 19:40:00+06\\")","(65,\\"2024-01-29 19:55:00+06\\")","(66,\\"2024-01-29 19:58:00+06\\")","(67,\\"2024-01-29 20:01:00+06\\")","(68,\\"2024-01-29 20:04:00+06\\")","(69,\\"2024-01-29 20:07:00+06\\")","(70,\\"2024-01-29 20:10:00+06\\")"}	from_buet	Ba-93-6087	t	altaf	\N	2024-01-29 14:12:37.207573+06	(23.7266832,90.3879756)	(37.3307017,-122.0416992)	{"(37.421998333333335,-122.084)","(37.412275,-122.08192166666667)","(37.41010333333333,-122.07694333333333)","(37.40792166666667,-122.06673)","(37.403758333333336,-122.05173833333333)","(37.399258333333336,-122.03277)","(37.399258333333336,-122.03277)","(37.39700166666667,-122.01190166666666)","(37.33032,-122.04479)","(37.33071833333333,-122.04375166666667)","(37.33071,-122.04258)"}	f	0	siddiq2	t
1786	2024-01-29 15:08:16.186189+06	4	morning	{"(27,\\"2024-01-29 12:40:00+06\\")","(28,\\"2024-01-29 12:42:00+06\\")","(29,\\"2024-01-29 12:44:00+06\\")","(30,\\"2024-01-29 12:46:00+06\\")","(31,\\"2024-01-29 12:50:00+06\\")","(32,\\"2024-01-29 12:52:00+06\\")","(33,\\"2024-01-29 12:54:00+06\\")","(34,\\"2024-01-29 12:58:00+06\\")","(35,\\"2024-01-29 13:00:00+06\\")","(70,\\"2024-01-29 13:10:00+06\\")"}	to_buet	BA-01-2345	t	altaf	reyazul	2024-01-29 15:14:46.6046+06	(23.7267164,90.3881888)	(23.7647567,90.360895)	{"(23.764756666666667,90.360895)","(23.764756666666667,90.360895)","(23.764756666666667,90.360895)"}	f	0	alamgir	t
1787	2024-01-29 15:14:51.580955+06	4	afternoon	{"(27,\\"2024-01-29 19:40:00+06\\")","(28,\\"2024-01-29 19:50:00+06\\")","(29,\\"2024-01-29 19:52:00+06\\")","(30,\\"2024-01-29 19:54:00+06\\")","(31,\\"2024-01-29 19:56:00+06\\")","(32,\\"2024-01-29 19:58:00+06\\")","(33,\\"2024-01-29 20:00:00+06\\")","(34,\\"2024-01-29 20:02:00+06\\")","(35,\\"2024-01-29 20:04:00+06\\")","(70,\\"2024-01-29 20:06:00+06\\")"}	from_buet	BA-01-2345	t	altaf	reyazul	2024-01-29 23:18:22.158268+06	(23.7647567,90.360895)	(23.7625974,90.3701842)	{"(23.76468,90.36215)","(23.76468,90.36215)","(23.76468,90.36215)","(23.764895,90.36317)","(23.764895,90.36317)","(23.764895,90.36317)","(23.765118333333334,90.36412833333333)","(23.765118333333334,90.36412833333333)","(23.765118333333334,90.36412833333333)","(23.764333333333333,90.36475666666666)","(23.764333333333333,90.36475666666666)","(23.764333333333333,90.36475666666666)","(23.76392,90.36567833333334)","(23.76392,90.36567833333334)","(23.76392,90.36567833333334)","(23.763133333333332,90.36701166666667)","(23.763133333333332,90.36701166666667)","(23.763133333333332,90.36701166666667)","(23.763403333333333,90.36802833333333)","(23.763403333333333,90.36802833333333)","(23.763403333333333,90.36802833333333)"}	f	0	alamgir	t
1939	2024-01-30 00:56:29.07057+06	7	morning	{"(50,\\"2024-01-30 12:40:00+06\\")","(51,\\"2024-01-30 12:42:00+06\\")","(52,\\"2024-01-30 12:43:00+06\\")","(53,\\"2024-01-30 12:46:00+06\\")","(54,\\"2024-01-30 12:47:00+06\\")","(55,\\"2024-01-30 12:48:00+06\\")","(56,\\"2024-01-30 12:50:00+06\\")","(57,\\"2024-01-30 12:52:00+06\\")","(58,\\"2024-01-30 12:53:00+06\\")","(59,\\"2024-01-30 12:54:00+06\\")","(60,\\"2024-01-30 12:56:00+06\\")","(61,\\"2024-01-30 12:58:00+06\\")","(62,\\"2024-01-30 13:00:00+06\\")","(63,\\"2024-01-30 13:02:00+06\\")","(70,\\"2024-01-30 13:00:00+06\\")"}	to_buet	Ba-46-1334	t	sohel55	\N	2024-01-30 02:00:17.416698+06	(23.7626292,90.3702478)	(23.7626699,90.3702059)	{"(23.874325,90.3888517)","(23.8743526,90.3901666)","(23.874255,90.3850317)","(23.874285,90.3870576)","(23.8743099,90.3882428)","(23.8743416,90.3893562)","(23.8743567,90.3905061)","(23.87438,90.3915867)","(23.87439,90.3926017)","(23.8744091,90.3937183)","(23.8744506,90.3949697)","(23.8745025,90.3961401)","(23.8745545,90.3973035)","(23.8746112,90.3984493)","(23.87462,90.3995454)","(23.87466,90.4006463)","(23.8735066,90.4007136)","(37.4226711,-122.0849872)","(23.7583291,90.3786724)","(23.8742593,90.3851502)","(23.8742757,90.3862376)","(23.8742901,90.3873217)","(23.8743101,90.3883149)","(23.8743435,90.3894298)","(23.874407,90.3937895)","(23.8744109,90.3940086)","(23.8744577,90.3950737)","(23.8745055,90.3961643)","(23.8745501,90.3971665)","(23.87462,90.399455)"}	f	0	nasir81	t
1940	2024-01-30 18:42:57.389505+06	7	afternoon	{"(50,\\"2024-01-30 19:40:00+06\\")","(51,\\"2024-01-30 19:48:00+06\\")","(52,\\"2024-01-30 19:50:00+06\\")","(53,\\"2024-01-30 19:52:00+06\\")","(54,\\"2024-01-30 19:54:00+06\\")","(55,\\"2024-01-30 19:56:00+06\\")","(56,\\"2024-01-30 19:58:00+06\\")","(57,\\"2024-01-30 20:00:00+06\\")","(58,\\"2024-01-30 20:02:00+06\\")","(59,\\"2024-01-30 20:04:00+06\\")","(60,\\"2024-01-30 20:06:00+06\\")","(61,\\"2024-01-30 20:08:00+06\\")","(62,\\"2024-01-30 20:10:00+06\\")","(63,\\"2024-01-30 20:12:00+06\\")","(70,\\"2024-01-30 20:14:00+06\\")"}	from_buet	Ba-46-1334	t	sohel55	\N	2024-01-30 18:50:36.374076+06	(23.7664933,90.3647317)	(23.7664916,90.3647319)	{"(23.7664083,90.364746)"}	f	0	nasir81	t
1992	2024-01-30 19:09:14.244506+06	1	evening	{"(1,\\"2024-02-05 23:30:00+06\\")","(2,\\"2024-02-05 23:37:00+06\\")","(3,\\"2024-02-05 23:40:00+06\\")","(4,\\"2024-02-05 23:42:00+06\\")","(5,\\"2024-02-05 23:44:00+06\\")","(6,\\"2024-02-05 23:56:00+06\\")","(7,\\"2024-02-05 23:59:00+06\\")","(8,\\"2024-02-05 00:02:00+06\\")","(9,\\"2024-02-05 00:05:00+06\\")","(10,\\"2024-02-05 00:08:00+06\\")","(11,\\"2024-02-05 00:11:00+06\\")","(70,\\"2024-02-05 00:14:00+06\\")"}	from_buet	Ba-19-0569	t	altaf	nazmul	2024-01-30 20:12:21.131647+06	(23.7663984,90.3647428)	(23.7666283,90.3646967)	{"(23.7633199,90.3621187)","(23.7664933,90.3647317)","(23.7660378,90.3649393)","(23.7655868,90.3651079)","(23.7647904,90.3653949)","(23.7643363,90.3655313)","(23.7641401,90.3650102)","(23.7639583,90.3643684)","(23.7637966,90.3637644)","(23.7635315,90.3628686)","(23.7631418,90.3615597)","(23.7628039,90.3603286)","(23.7624547,90.3591464)","(23.7619579,90.3588889)","(23.7666283,90.3646967)"}	f	0	siddiq2	t
1933	2024-01-31 02:06:44.0287+06	5	morning	{"(36,\\"2024-01-31 02:24:22.106+06\\")","(37,\\"2024-01-31 02:25:56.057+06\\")","(38,\\"2024-01-31 02:26:57.571+06\\")","(39,\\"2024-01-31 02:28:00.589+06\\")","(40,\\"2024-01-31 02:29:33.261+06\\")","(70,\\"2024-01-31 02:32:09.752+06\\")"}	to_buet	Ba-77-7044	t	rashed3	\N	2024-01-31 02:32:26.830395+06	(23.7660883,90.364925)	(23.7275268,90.3917003)	{"(23.7649583,90.36534)","(23.7642127,90.3653061)","(23.763966,90.3644196)","(23.7635667,90.3629833)","(23.7631566,90.3616)","(23.7626922,90.3599427)","(23.7619673,90.3588807)","(23.7606257,90.3588821)","(23.7594134,90.3591298)","(23.7582786,90.3597956)","(23.757416,90.3606085)","(23.7567556,90.3619079)","(23.7553636,90.3635747)","(23.7540429,90.3651788)","(23.7528579,90.3665731)","(23.751739,90.3676538)","(23.7506441,90.3684183)","(23.7496062,90.3691326)","(23.7485527,90.3698621)","(23.7475619,90.3705334)","(23.7464753,90.3712699)","(23.7454449,90.3719636)","(23.7445081,90.3725616)","(23.7434362,90.3732948)","(23.7424289,90.3739508)","(23.7414579,90.374452)","(23.7402636,90.375049)","(23.7391591,90.3756102)","(23.7382941,90.3762665)","(23.738683,90.3756855)","(23.7395038,90.3753022)","(23.7384414,90.3760868)","(23.7385189,90.3774315)","(23.7388197,90.3793567)","(23.7398813,90.3807054)","(23.7404818,90.3823661)","(23.7397015,90.383306)","(23.738315,90.3836105)","(23.7366835,90.3840001)","(23.7351339,90.38438)","(23.7333583,90.3848333)","(23.7324607,90.3857894)","(23.7321584,90.3870136)","(23.72971,90.38755)","(23.7277783,90.38928)","(23.7277284,90.3907508)","(23.7276,90.3917054)"}	f	0	reyazul	t
1930	2024-01-31 15:14:10.296909+06	4	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-83-8014	t	rafiqul	\N	2024-01-31 15:30:54.236178+06	(23.7267071,90.3880359)	(23.7267111,90.3881077)	{"(23.7267133,90.3880396)"}	f	0	mahmud64	t
1924	2024-01-31 16:58:29.913838+06	2	morning	{NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-22-4326	t	rafiqul	\N	2024-01-31 16:59:59.175579+06	(23.7481383,90.3800983)	(23.7407144,90.3830852)	{"(23.747948333333333,90.38021)","(23.74714,90.38071)","(23.746336666666668,90.381165)","(23.745058333333333,90.381905)","(23.743881666666667,90.38228333333333)","(23.74266,90.38259)","(23.741388333333333,90.38290666666667)"}	f	0	jamal7898	t
1931	2024-01-31 17:11:19.993161+06	4	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-01-31 17:12:07.136+06\\")"}	from_buet	Ba-83-8014	t	rafiqul	\N	2024-01-31 18:17:20.504623+06	(23.7272617,90.3894852)	(23.7648684,90.362928)	{"(23.72742424,90.38952306)","(23.72723315,90.39084778)","(23.72747979,90.38972707)","(23.72839502,90.38905589)","(23.72916022,90.38816033)","(23.73006908,90.38765401)","(23.73106458,90.38708456)","(23.73211297,90.38693844)","(23.73249312,90.385646)","(23.7333372,90.38489895)","(23.73433357,90.38466604)","(23.73523457,90.38425773)","(23.73648617,90.38403921)","(23.73740914,90.38378537)","(23.73833805,90.383601)","(23.73927028,90.38336656)","(23.73933127,90.38230218)","(23.73923418,90.3812476)","(23.73898232,90.38030386)","(23.73867508,90.37932409)","(23.73852853,90.37829491)","(23.73842503,90.37716909)","(23.73863024,90.37590965)","(23.73962306,90.37550073)","(23.74075863,90.37480071)","(23.74194087,90.37422286)","(23.74288106,90.37367614)","(23.74389185,90.37306376)","(23.74489102,90.37226392)","(23.74580263,90.37164569)","(23.74726573,90.3705733)","(23.74833498,90.36976167)","(23.7496622,90.36912699)","(23.75073574,90.36829627)","(23.75153495,90.36777138)","(23.75268138,90.36688452)","(23.75353426,90.36601961)","(23.75420882,90.36514768)","(23.75499203,90.3641664)","(23.75595636,90.36437693)","(23.7568904,90.36415729)","(23.75786953,90.36380382)","(23.75873282,90.36409829)","(23.75962336,90.36386946)","(23.76049656,90.36351761)","(23.76140771,90.36332804)","(23.76227281,90.36301732)","(23.76314569,90.36273093)","(23.76394367,90.36323979)","(23.76479898,90.36290691)"}	f	0	mahmud64	t
1100	2024-01-28 00:31:14.828099+06	3	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-35-1461	t	altaf	nazmul	2024-02-01 19:32:48.812563+06	(23.7623975,90.3646323)	(23.7728898,90.3607467)	{"(23.77292266,90.36075484)","(23.77292266,90.36075484)","(23.77292266,90.36075484)"}	f	0	rashid56	t
1132	2024-01-28 09:15:49.433306+06	6	afternoon	{"(41,\\"2024-01-28 19:40:00+06\\")","(42,\\"2024-01-28 19:56:00+06\\")","(43,\\"2024-01-28 19:58:00+06\\")","(44,\\"2024-01-28 20:00:00+06\\")","(45,\\"2024-01-28 20:02:00+06\\")","(46,\\"2024-01-28 20:04:00+06\\")","(47,\\"2024-01-28 20:06:00+06\\")","(48,\\"2024-01-28 20:08:00+06\\")","(49,\\"2024-01-28 20:10:00+06\\")","(70,\\"2024-01-28 20:12:00+06\\")"}	from_buet	Ba-17-2081	t	arif43	nazmul	2024-01-28 09:45:07.738489+06	(23.7266771,90.388158)	(23.7266784,90.3882818)	{"(23.72655019,90.38848189)","(23.72696112,90.38936913)","(23.72772774,90.39008871)","(23.72809878,90.39110518)","(23.72839477,90.39223458)","(23.72816985,90.39335134)","(23.72780276,90.39453776)","(23.7280286,90.39549392)","(23.72893826,90.39536566)","(23.72997105,90.39542245)","(23.73100256,90.39525183)","(23.73012462,90.39548402)","(23.7290751,90.39542807)","(23.72809697,90.39529247)","(23.72718984,90.39528533)","(23.7267802,90.39425865)","(23.72692749,90.39319299)","(23.72710812,90.39220914)","(23.72732432,90.39121605)","(23.72756128,90.39025052)","(23.72692572,90.3894264)"}	f	0	abdulbari4	t
1932	2024-02-01 20:55:09.481758+06	4	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-02 12:47:22.689+06\\")"}	from_buet	Ba-83-8014	t	rafiqul	\N	2024-02-02 12:49:47.706461+06	(23.7629733,90.3703847)	(23.7275682,90.3917004)	{"(23.7276,90.3917)","(23.7275682,90.3917004)"}	f	0	mahmud64	t
2221	2024-02-09 10:28:33.023756+06	5	morning	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:28:37.958+06\\")"}	to_buet	Ba-35-1461	t	ibrahim	nazmul	2024-02-09 10:43:54.057066+06	(23.7276,90.3917)	(23.7275679,90.3917004)	{"(23.7275743,90.3917007)"}	f	0	mahabhu	t
2009	2024-02-02 15:42:11.283236+06	6	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-02 16:15:01.019+06\\")"}	from_buet	Ba-35-1461	t	rafiqul	\N	2024-02-02 16:27:07.931376+06	(23.7276,90.3917)	(23.7275838,90.3917005)	{"(23.7648733,90.3653667)","(23.7645031,90.3654853)","(23.7641497,90.3650402)","(23.7639833,90.3644567)","(23.7638116,90.3638234)","(23.7636397,90.3632387)","(23.7634616,90.3626133)","(23.7632783,90.362005)","(23.7630968,90.3613995)","(23.76241,90.3590017)","(23.7617215,90.3589035)","(23.7612486,90.3589302)","(23.7606,90.35889)","(23.7585283,90.3596133)","(23.7580886,90.3599568)","(23.7552767,90.363675)","(23.7549367,90.3640867)","(23.7544,90.364755)","(23.7538401,90.3654132)","(23.7532599,90.3660852)","(23.7527252,90.3667217)","(23.7521438,90.3673408)","(23.7514803,90.367835)","(23.7507733,90.368325)","(23.7500894,90.368798)","(23.7493783,90.3692901)","(23.748685,90.3697718)","(23.7479735,90.370255)","(23.747265,90.3707333)","(23.7465733,90.3712017)","(23.745873,90.3716733)","(23.74518,90.3721417)","(23.7445134,90.3725567)","(23.7438169,90.3730334)","(23.7431234,90.3735101)","(23.7424302,90.3739502)","(23.7416697,90.3743279)","(23.7409301,90.3747134)","(23.7401884,90.3750834)","(23.7394514,90.3754565)","(23.7387278,90.3758431)","(23.7382881,90.3762742)","(23.7386099,90.3757791)","(23.7390961,90.3755225)","(23.7395632,90.3752781)","(23.7390285,90.3756786)","(23.7383976,90.3761686)","(23.7384951,90.3771404)","(23.7386264,90.3781189)","(23.7387567,90.3790406)","(23.7388567,90.3795495)","(23.7389501,90.3800361)","(23.7392043,90.3808549)","(23.7398817,90.380695)","(23.7402218,90.3811281)","(23.7403801,90.3819349)","(23.7405283,90.3827098)","(23.74038,90.3831792)","(23.7397053,90.3832883)","(23.7390403,90.3834301)","(23.7383795,90.3835895)","(23.7377132,90.3837803)","(23.7370269,90.3839301)","(23.7363717,90.3840601)","(23.7357267,90.3842167)","(23.7350732,90.3843967)","(23.734415,90.3845635)","(23.733788,90.3847131)","(23.7331683,90.3848867)","(23.7326061,90.3851288)","(23.7324705,90.3857902)","(23.732565,90.3864833)","(23.7325621,90.3871518)","(23.7316117,90.3869603)","(23.7310527,90.3870348)","(23.7305355,90.3871928)","(23.7300948,90.3873619)","(23.7296008,90.3876295)","(23.7291602,90.3879549)","(23.7287433,90.3883199)","(23.7283532,90.388695)","(23.7279634,90.3890949)","(23.7276243,90.389439)","(23.7275883,90.3902752)","(23.7277466,90.3907988)","(23.7279398,90.3913367)","(23.7275878,90.3917004)"}	f	0	alamgir	t
2222	2024-02-09 10:44:04.075992+06	5	afternoon	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:44:08.967+06\\")"}	from_buet	Ba-35-1461	t	ibrahim	nazmul	2024-02-09 10:46:18.534544+06	(23.7275682,90.3917004)	(23.7275686,90.3917004)	{"(23.7275675,90.3917007)"}	f	0	mahabhu	t
2008	2024-02-02 19:40:28.46654+06	6	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-35-1461	t	rafiqul	\N	2024-02-02 22:31:33.411593+06	(23.765635,90.365095)	(23.7653685,90.3651876)	{"(23.7626499,90.3598)","(23.7624735,90.359203)","(23.7619189,90.3588915)","(23.7614065,90.3589234)","(23.7609,90.35893)","(23.7603947,90.3588877)","(23.7599001,90.3589495)","(23.7594148,90.3591332)","(23.758946,90.359368)","(23.7585274,90.3596138)","(23.7580886,90.3599568)","(23.7576788,90.3603374)","(23.7573053,90.3607121)","(23.7571015,90.3611901)","(23.7568606,90.3617874)","(23.7563121,90.3624558)","(23.7557737,90.3630793)","(23.7551984,90.3637684)","(23.7546567,90.3644367)","(23.7541235,90.3650852)","(23.7535467,90.3657518)","(23.7530315,90.3663601)","(23.7524718,90.3670183)","(23.7518234,90.3675801)","(23.7511352,90.3680801)","(23.7504491,90.3685505)","(23.749737,90.3690417)","(23.7490431,90.3695251)","(23.74837,90.3699901)","(23.74766,90.3704667)","(23.7469667,90.3709333)","(23.7462618,90.3714119)","(23.7455777,90.371873)","(23.7448882,90.3723303)","(23.7442149,90.372763)","(23.7434984,90.3732516)","(23.7428323,90.3737038)","(23.7420718,90.3741136)","(23.7413535,90.3745018)","(23.7406181,90.3748701)","(23.7398686,90.3752368)","(23.7391599,90.3756102)","(23.738456,90.3760511)","(23.7388095,90.3756723)","(23.739308,90.3754147)","(23.7397805,90.3752312)","(23.7663067,90.3648533)","(23.7654684,90.3651552)","(23.765385,90.365185)","(23.765385,90.365185)"}	f	0	alamgir	t
2010	2024-02-03 02:00:30.432902+06	6	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-35-1461	t	rafiqul	\N	2024-02-03 02:21:31.972824+06	(23.7654267,90.36517)	(23.7571217,90.3609075)	{"(23.75712,90.36088)"}	f	0	alamgir	t
2223	2024-02-09 10:46:30.002967+06	5	evening	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:46:34.971+06\\")"}	from_buet	Ba-35-1461	t	ibrahim	nazmul	2024-02-09 10:50:58.024208+06	(23.7275684,90.3917004)	(23.7275677,90.3917005)	{"(23.7275675,90.3917007)"}	f	0	mahabhu	t
2029	2024-02-01 23:24:27.841567+06	5	morning	{"(36,\\"2024-02-01 23:43:37.427+06\\")","(37,\\"2024-02-01 23:46:25.051+06\\")","(38,\\"2024-02-01 23:48:20.947+06\\")","(39,\\"2024-02-01 23:49:54.932+06\\")","(40,\\"2024-02-01 23:51:40.719+06\\")","(70,\\"2024-02-01 23:54:27.408+06\\")"}	to_buet	Ba-19-0569	t	rahmatullah	\N	2024-02-01 23:55:36.4686+06	(23.7276,90.3917)	(23.7275675,90.3917005)	{"(23.7643783,90.3655217)","(23.76413,90.3649805)","(23.7639583,90.3643683)","(23.7637883,90.363735)","(23.7636147,90.3631502)","(23.7634398,90.3625299)","(23.7629853,90.3610403)","(23.7625683,90.3595056)","(23.7616309,90.3588977)","(23.7605135,90.3588799)","(23.7591929,90.3592394)","(23.7581483,90.3599098)","(23.7571333,90.3608661)","(23.7570507,90.3613632)","(23.7566131,90.3621009)","(23.7560355,90.3627703)","(23.7554866,90.3634248)","(23.7549367,90.3640867)","(23.7544267,90.3647233)","(23.7539463,90.365291)","(23.7533672,90.3659612)","(23.7528594,90.3665706)","(23.7522403,90.3672697)","(23.7515454,90.3677886)","(23.75084,90.3682802)","(23.7501216,90.368775)","(23.7494749,90.3692234)","(23.7488493,90.3696603)","(23.7481058,90.3701665)","(23.7474939,90.3705771)","(23.7467392,90.3710897)","(23.746062,90.3715418)","(23.7453449,90.3720299)","(23.74467,90.3724602)","(23.7439816,90.3729215)","(23.7433031,90.3733883)","(23.7426694,90.3738104)","(23.7419106,90.3741906)","(23.7411078,90.3746249)","(23.7403366,90.3750101)","(23.7395918,90.3753817)","(23.7388803,90.3757584)","(23.7383764,90.3762794)","(23.7395087,90.3753061)","(23.7388731,90.3757675)","(23.738622,90.3781165)","(23.7389698,90.3801444)","(23.7401989,90.3810349)","(23.7405804,90.3829794)","(23.7392125,90.3834244)","(23.7376194,90.3838019)","(23.7361572,90.3841101)","(23.7345389,90.3845399)","(23.7327824,90.3849899)","(23.7325445,90.38645)","(23.7312018,90.3870402)","(23.72906,90.38804)","(23.7273701,90.389659)","(23.7275433,90.3901345)","(23.7278341,90.3910534)","(23.7277747,90.3916944)"}	f	0	altaf	t
1934	2024-02-09 10:54:05.009695+06	5	afternoon	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:55:00.044+06\\")"}	from_buet	Ba-77-7044	t	rashed3	\N	2024-02-09 10:55:34.394021+06	(23.7276,90.3917)	(23.7275682,90.3917004)	{"(23.7276,90.3917)"}	f	0	reyazul	t
2133	2024-02-06 19:54:49.635004+06	7	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	BA-01-2345	t	altaf	nazmul	2024-02-07 14:48:30.442322+06	(23.7626608,90.3702206)	(23.7626755,90.3702402)	{"(23.740763333333334,90.38307833333333)","(23.740763333333334,90.38307833333333)","(23.740763333333334,90.38307833333333)","(23.7626687,90.3702073)"}	f	0	jamal7898	t
1935	2024-02-09 10:55:39.816801+06	5	evening	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:55:44.007+06\\")"}	from_buet	Ba-77-7044	t	rashed3	\N	2024-02-09 11:00:45.08317+06	(23.7275686,90.3917009)	(23.7275674,90.3917006)	{"(23.7275677,90.3917004)"}	f	0	reyazul	t
2161	2024-02-07 14:59:32.16427+06	8	morning	{"(64,\\"2024-02-07 12:10:00+06\\")","(65,\\"2024-02-07 12:13:00+06\\")","(66,\\"2024-02-07 12:18:00+06\\")","(67,\\"2024-02-07 12:20:00+06\\")","(68,\\"2024-02-07 12:22:00+06\\")","(69,\\"2024-02-07 12:25:00+06\\")","(70,\\"2024-02-07 12:40:00+06\\")"}	to_buet	Ba-12-8888	t	altaf	nazmul	\N	(23.7626675,90.3702308)	\N	{"(23.7626823,90.3702164)"}	f	0	sharif86r	t
2164	2024-02-07 15:35:45.935618+06	2	morning	{"(12,\\"1970-01-01 06:00:00+06\\")","(13,\\"1970-01-01 06:00:00+06\\")","(14,\\"1970-01-01 06:00:00+06\\")","(15,\\"1970-01-01 06:00:00+06\\")","(16,\\"1970-01-01 06:00:00+06\\")","(70,\\"1970-01-01 06:00:00+06\\")"}	to_buet	Ba-17-3886	t	altaf	nazmul	\N	(23.7626796,90.3702159)	\N	{"(23.7626839,90.3702222)"}	f	0	siddiq2	t
2053	2024-02-09 11:01:01.058033+06	5	morning	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 11:01:05.985+06\\")"}	to_buet	Ba-22-4326	t	rashed3	nazmul	2024-02-09 11:02:51.355694+06	(23.7276,90.3917)	(23.7275685,90.3917004)	{"(23.7275743,90.3917007)"}	f	0	ASADUZZAMAN	t
2311	2024-02-07 16:05:13.253608+06	3	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-35-1461	t	altaf	nazmul	2024-02-07 16:06:07.078519+06	(23.7626809,90.3702142)	(23.7626744,90.3702182)	{"(23.762687,90.3702104)"}	f	0	mahbub777	t
2312	2024-02-07 16:07:02.122946+06	3	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-35-1461	t	altaf	nazmul	2024-02-07 16:07:08.64287+06	(23.7626882,90.3702101)	(23.7626864,90.3702097)	{"(23.7626864,90.3702097)"}	f	0	mahbub777	t
2054	2024-02-09 11:03:21.063747+06	5	afternoon	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 11:03:25.977+06\\")"}	from_buet	Ba-22-4326	t	rashed3	nazmul	2024-02-09 11:04:26.010806+06	(23.7276,90.3917)	(23.7275675,90.3917006)	{"(23.7275743,90.3917007)"}	f	0	ASADUZZAMAN	t
2313	2024-02-07 16:12:57.532015+06	3	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-35-1461	t	altaf	nazmul	2024-02-07 17:53:05.068558+06	(23.762676,90.3702415)	(23.762682,90.3702159)	{"(23.7626869,90.3702193)","(23.7626855,90.3702076)","(23.7626792,90.3702124)","(23.7626759,90.3702081)"}	f	2	mahbub777	t
2017	2024-02-09 11:05:15.057455+06	8	morning	{NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 11:05:20.022+06\\")"}	to_buet	Ba-85-4722	t	rashed3	\N	2024-02-09 11:06:04.0196+06	(23.7276,90.3917)	(23.7275686,90.3917004)	{"(23.7275743,90.3917007)"}	f	0	rashid56	t
2055	2024-02-09 11:06:56.017838+06	5	evening	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 11:07:00.975+06\\")"}	from_buet	Ba-22-4326	t	rashed3	nazmul	2024-02-09 11:08:27.202194+06	(23.7276,90.3917)	(23.7275685,90.3917004)	{"(23.7275743,90.3917007)"}	f	0	ASADUZZAMAN	t
2149	2024-02-03 02:27:26.668403+06	5	morning	{NULL,"(37,\\"2024-02-03 02:36:13.157+06\\")","(38,\\"2024-02-03 02:40:04.731+06\\")","(39,\\"2024-02-03 02:43:11.665+06\\")","(40,\\"2024-02-03 02:47:02.649+06\\")","(70,\\"2024-02-03 20:25:22.583+06\\")"}	to_buet	Ba-35-1461	t	arif43	nazmul	2024-02-03 20:25:49.592864+06	(23.76479,90.365395)	(23.7275567,90.3917012)	{"(23.7645899,90.3654602)","(23.7641791,90.3651597)","(23.7640079,90.364545)","(23.7638432,90.3639419)","(23.763665,90.3633206)","(23.7634948,90.3627313)","(23.7633133,90.3621218)","(23.7631214,90.3614863)","(23.7629498,90.3608901)","(23.7627899,90.3602684)","(23.7626161,90.3596785)","(23.7624275,90.3590591)","(23.7620054,90.3588835)","(23.7615043,90.3589169)","(23.7610044,90.3589301)","(23.7605168,90.3588805)","(23.7599776,90.3589364)","(23.7595058,90.3590893)","(23.7590332,90.3593216)","(23.7585796,90.3595811)","(23.7581502,90.3599098)","(23.7577339,90.3602707)","(23.7573619,90.3606604)","(23.7571057,90.3610809)","(23.7569602,90.3616513)","(23.7564185,90.3623344)","(23.7558515,90.3629871)","(23.7553034,90.3636434)","(23.7547583,90.3643097)","(23.7542302,90.3649617)","(23.7536535,90.3656283)","(23.7531108,90.3662656)","(23.7525503,90.3669249)","(23.7519525,90.3674845)","(23.7512668,90.3679917)","(23.7505766,90.3684601)","(23.7498687,90.36895)","(23.7492048,90.3694127)","(23.7485217,90.3698854)","(23.7478084,90.3703668)","(23.7471318,90.3708218)","(23.7464751,90.3712702)","(23.7458061,90.3717183)","(23.7451382,90.372171)","(23.7444118,90.3726267)","(23.7437168,90.3731001)","(23.743025,90.3735753)","(23.7423222,90.373999)","(23.7415994,90.374366)","(23.7408601,90.3747486)","(23.7401172,90.3751167)","(23.7393483,90.3755133)","(23.738628,90.3758984)","(23.739166,90.3754905)","(23.7396567,90.3752282)","(23.7347051,90.3844951)","(23.7340926,90.3846321)","(23.7334171,90.3848151)","(23.7327804,90.3849898)","(23.7324695,90.385514)","(23.732523,90.3861867)","(23.732625,90.3869148)","(23.7320649,90.3869498)","(23.7315155,90.3869588)","(23.7310033,90.387045)","(23.7305339,90.3871921)","(23.730093,90.387362)","(23.7296017,90.3876288)","(23.7291601,90.3879544)","(23.7287431,90.3883196)","(23.728353,90.388695)","(23.7279634,90.3890946)","(23.7276237,90.3894399)","(23.7276037,90.3903194)","(23.7277651,90.3908467)","(23.7279577,90.3913836)","(23.7275677,90.3917011)","(23.7276,90.3917)"}	f	0	khairul	t
2079	2024-02-06 08:00:16.411533+06	5	evening	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:16:47.939+06\\")"}	from_buet	Ba-34-7413	t	ibrahim	nazmul	2024-02-09 10:17:19.010068+06	(23.7728923,90.3607481)	(23.7275682,90.3917004)	{"(23.77291265,90.36078955)","(23.7275696,90.3917003)"}	f	0	mahabhu	t
2137	2024-02-08 11:02:05.674961+06	8	morning	{NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:15:09.947+06\\")"}	to_buet	Ba-36-1921	t	rafiqul	nazmul	2024-02-09 20:17:17.085045+06	(23.7525217,90.3538429)	(23.7626577,90.3701649)	{"(23.75248784,90.35385556)","(23.76002136,90.36689164)","(23.76009567,90.36738587)","(23.76066827,90.36762518)","(23.76107535,90.36735947)","(23.76163621,90.36740939)","(23.76223549,90.36685081)","(23.76248042,90.36747988)","(23.76266301,90.36805049)","(23.76284516,90.36868806)","(23.76323172,90.36910766)","(23.76317162,90.36999637)","(23.76282085,90.37031665)","(23.7276,90.3917)"}	f	0	rashid56	t
2150	2024-02-03 20:29:40.596129+06	5	afternoon	{"(36,\\"2024-02-03 20:31:47.413+06\\")","(37,\\"2024-02-03 20:36:33.414+06\\")","(38,\\"2024-02-03 20:38:29.933+06\\")","(39,\\"2024-02-03 20:40:06.871+06\\")","(40,\\"2024-02-03 20:42:29.778+06\\")","(70,\\"2024-02-03 20:48:23.916+06\\")"}	from_buet	Ba-35-1461	t	arif43	nazmul	2024-02-03 20:51:18.151106+06	(23.7276,90.3917)	(23.7275171,90.3917008)	{"(23.7275747,90.3917011)","(23.766265,90.3648667)","(23.7653851,90.3651851)","(23.7645435,90.3654723)","(23.764162,90.3650983)","(23.7639921,90.3644893)","(23.7638266,90.3638835)","(23.7636499,90.3632703)","(23.7634781,90.3626715)","(23.7632967,90.3620633)","(23.763113,90.3614564)","(23.7629495,90.3608871)","(23.7627899,90.3602685)","(23.7626358,90.3597588)","(23.7624293,90.3590651)","(23.7620049,90.3588648)","(23.7614827,90.3589146)","(23.7609545,90.3589303)","(23.7604214,90.3588882)","(23.7599205,90.3589457)","(23.7594375,90.3591195)","(23.7589666,90.3593559)","(23.7585076,90.359628)","(23.7581063,90.3599415)","(23.7576973,90.360317)","(23.7573422,90.36068)","(23.7571077,90.3611113)","(23.7568605,90.3617724)","(23.7563149,90.3624542)","(23.7557489,90.3631119)","(23.7551732,90.3638001)","(23.75463,90.3644681)","(23.7540965,90.3651171)","(23.7535201,90.3657836)","(23.7529798,90.3664235)","(23.7524969,90.3669887)","(23.7518578,90.367555)","(23.7512315,90.3680154)","(23.7505143,90.3685057)","(23.749866,90.3689514)","(23.7491107,90.3694788)","(23.7483898,90.3699754)","(23.747758,90.3704012)","(23.7470354,90.3708873)","(23.7461948,90.3714551)","(23.7454782,90.37194)","(23.7447866,90.3723902)","(23.7441134,90.372833)","(23.7434961,90.3732527)","(23.742834,90.3737029)","(23.7420746,90.3741136)","(23.7413868,90.3744852)","(23.740686,90.3748359)","(23.7399068,90.3752174)","(23.739209,90.37559)","(23.7385392,90.3759518)","(23.7392136,90.3754628)","(23.7396799,90.3752165)","(23.7389036,90.3757474)","(23.7383907,90.376367)","(23.7385048,90.3772786)","(23.7386295,90.3781382)","(23.7387731,90.3791268)","(23.7389416,90.3799975)","(23.7392385,90.3808448)","(23.7398785,90.3807057)","(23.7402374,90.381087)","(23.7403772,90.3818926)","(23.7405286,90.3827104)","(23.7403405,90.3831992)","(23.7397019,90.3832955)","(23.7391391,90.3834101)","(23.7384989,90.38355)","(23.7378657,90.3837428)","(23.7371249,90.3839101)","(23.7364654,90.3840421)","(23.7358493,90.3841865)","(23.735284,90.3843401)","(23.7346174,90.3845196)","(23.7339702,90.3846673)","(23.7333256,90.3848416)","(23.7327381,90.3850608)","(23.7324829,90.3856161)","(23.7325387,90.3863172)","(23.7326587,90.3869923)","(23.7318661,90.3871311)","(23.7307978,90.387114)","(23.7298859,90.3874568)","(23.72898,90.3881053)","(23.7282289,90.3888284)","(23.72748,90.389658)","(23.7277971,90.390943)","(23.727827,90.3916868)"}	f	2	khairul	t
2077	2024-02-04 14:33:26.147705+06	5	morning	{NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-34-7413	t	ibrahim	nazmul	2024-02-04 15:41:59.714432+06	(23.7267047,90.3882934)	(23.7738773,90.3607218)	{"(23.72670142,90.38834294)","(23.72662115,90.38934122)","(23.72706564,90.38846667)","(23.72701156,90.38740833)","(23.72692634,90.38636139)","(23.72789826,90.38605294)","(23.72883413,90.38580855)","(23.729761,90.38576675)","(23.73074099,90.38571427)","(23.73159195,90.38527448)","(23.73282386,90.38448791)","(23.73372323,90.38484045)","(23.7346514,90.38446164)","(23.73569549,90.38407087)","(23.73685971,90.38382624)","(23.73789558,90.38391045)","(23.73889876,90.3835447)","(23.7399763,90.383203)","(23.74124132,90.38282518)","(23.74251187,90.38251853)","(23.74354504,90.38240553)","(23.74449667,90.38205572)","(23.74547177,90.38182319)","(23.74655476,90.38107447)","(23.7474218,90.38075053)","(23.74912816,90.3792149)","(23.75048469,90.37877427)","(23.75142447,90.37800705)","(23.75242425,90.37745536)","(23.75365548,90.37673968)","(23.75555865,90.37574798)","(23.75713535,90.37464479)","(23.75807558,90.37421568)","(23.75961408,90.37324526)","(23.76063318,90.37273955)","(23.76139989,90.37216997)","(23.76218901,90.3716932)","(23.76351869,90.37098501)","(23.764777,90.37049157)","(23.7656762,90.36990339)","(23.76704277,90.36948851)","(23.76806456,90.36922452)","(23.76936847,90.36843412)","(23.77037556,90.36823122)","(23.77127927,90.36776257)","(23.77246578,90.36716057)","(23.77339877,90.36723635)","(23.77392645,90.36622396)","(23.77409134,90.36524519)","(23.77467,90.36447327)","(23.77440115,90.3633982)","(23.77409111,90.36231585)","(23.77359141,90.36138951)"}	f	0	mahabhu	t
2078	2024-02-04 13:40:42.447506+06	5	afternoon	{NULL,"(37,\\"2024-02-04 14:13:49.626+06\\")","(38,\\"2024-02-04 14:09:40.63+06\\")","(39,\\"2024-02-04 14:06:04.644+06\\")","(40,\\"2024-02-04 14:04:13.311+06\\")","(70,\\"2024-02-04 13:42:07.613+06\\")"}	from_buet	Ba-34-7413	t	ibrahim	nazmul	2024-02-04 14:17:08.831197+06	(23.7277025,90.391553)	(23.758565,90.364045)	{"(23.7277005,90.3915536)","(23.7272151,90.3917681)","(23.7267545,90.3918323)","(23.7262922,90.3919235)","(23.7261866,90.3914254)","(23.726548,90.3908094)","(23.7270001,90.3901624)","(23.7272766,90.3897504)","(23.727589,90.3893203)","(23.7281956,90.3888225)","(23.7285256,90.3884753)","(23.7288433,90.3881179)","(23.7292273,90.3878095)","(23.7323337,90.3854034)","(23.732539,90.3849662)","(23.7329863,90.3848359)","(23.7334396,90.3847276)","(23.7338888,90.384657)","(23.7343437,90.3845413)","(23.7347989,90.3843992)","(23.7352286,90.3842399)","(23.735816,90.384099)","(23.7362957,90.3839276)","(23.7368577,90.3838719)","(23.7375922,90.3837157)","(23.738055,90.3836674)","(23.7385034,90.3835617)","(23.7389441,90.3833578)","(23.7393894,90.3832737)","(23.7394432,90.3827815)","(23.7393307,90.3823006)","(23.739173,90.3814846)","(23.7390219,90.3806199)","(23.7388026,90.3796488)","(23.7386602,90.3788551)","(23.738571,90.3783634)","(23.7384856,90.3778672)","(23.7383949,90.3773851)","(23.7383121,90.3768871)","(23.7382914,90.3763953)","(23.7385267,90.3759654)","(23.7389219,90.3756781)","(23.7393427,90.3754623)","(23.7397452,90.3751643)","(23.7402104,90.3750361)","(23.7408624,90.3747133)","(23.7413335,90.3744239)","(23.7420379,90.3740933)","(23.7425203,90.3737572)","(23.7431309,90.373406)","(23.7436047,90.3730969)","(23.7441206,90.3727575)","(23.7446899,90.3723246)","(23.7450767,90.372024)","(23.7454949,90.3717077)","(23.7459099,90.3714097)","(23.7463337,90.3711167)","(23.7467796,90.3708159)","(23.7471771,90.3705583)","(23.7475997,90.3702801)","(23.7480531,90.370003)","(23.7484648,90.3697361)","(23.7488765,90.3695191)","(23.74927,90.3692409)","(23.7498073,90.3689208)","(23.7502894,90.3685247)","(23.7507021,90.3682338)","(23.7511345,90.3679947)","(23.7514487,90.3676382)","(23.7518593,90.3673785)","(23.7523424,90.3670369)","(23.7527357,90.3667451)","(23.7530168,90.3663358)","(23.7534395,90.3658951)","(23.7537416,90.3655136)","(23.7540984,90.3651801)","(23.7544818,90.3646903)","(23.755042,90.3642056)","(23.7554833,90.3643758)","(23.7560664,90.3642333)","(23.7566818,90.3640182)","(23.7572545,90.3638196)","(23.7578518,90.3635931)","(23.7583087,90.3635162)","(23.7584806,90.3639753)"}	f	1	mahabhu	t
2107	2024-02-04 18:19:32.381476+06	7	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-46-1334	t	altaf	nazmul	2024-02-04 18:20:08.40847+06	(23.8318623,90.3532059)	(23.8318692,90.35325)	{"(23.8318551,90.3532057)","(23.8318692,90.35325)"}	f	0	ASADUZZAMAN	t
2109	2024-02-05 22:51:30.092852+06	7	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-46-1334	t	altaf	nazmul	2024-02-05 23:09:28.494899+06	(23.8318706,90.3532144)	(23.8318746,90.3532107)	{"(23.831872,90.3532168)","(23.8318757,90.3532133)","(23.8318695,90.3532137)","(23.8318628,90.3532185)","(23.831881,90.3532168)"}	f	0	ASADUZZAMAN	t
2131	2024-02-05 23:19:23.516182+06	7	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	BA-01-2345	t	altaf	nazmul	2024-02-06 00:36:59.129703+06	(23.8318698,90.3532269)	(23.8318708,90.3532148)	{"(23.8318731,90.3532112)","(23.8318648,90.3532136)","(23.8301727,90.3524148)","(23.8318707,90.3532272)","(23.8318658,90.3532259)","(23.8318582,90.3532063)","(23.8318689,90.3532213)","(23.831863,90.3532112)","(23.8318639,90.3532362)","(23.8318668,90.3532187)","(23.8318724,90.3532007)","(23.8318687,90.3532153)","(23.8318872,90.3532129)","(23.8318773,90.3532055)","(23.8318516,90.3532023)","(23.8318531,90.3532093)","(23.8318705,90.3532156)"}	f	22	jamal7898	t
2132	2024-02-06 10:19:35.659477+06	7	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	BA-01-2345	t	altaf	nazmul	2024-02-06 10:30:30.281269+06	(23.7266902,90.3879919)	(23.7266817,90.3880168)	{"(23.72667916,90.38799154)"}	f	0	jamal7898	t
2108	2024-02-05 20:40:48.094045+06	7	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-46-1334	t	altaf	nazmul	2024-02-05 20:41:41.537487+06	(23.8318808,90.3532134)	(23.8318667,90.3532209)	{"(23.8318711,90.3532043)"}	f	1	ASADUZZAMAN	t
2162	2024-02-06 10:30:36.791862+06	8	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-06 11:05:20.955+06\\")"}	from_buet	Ba-12-8888	t	altaf	nazmul	2024-02-06 11:19:48.992364+06	(23.7266776,90.3879838)	(23.7260613,90.3911528)	{"(23.72667978,90.38800051)","(23.72655213,90.3890882)","(23.72599893,90.38989607)","(23.72630644,90.39083014)"}	f	0	sharif86r	t
2163	2024-02-07 15:21:48.683591+06	8	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-12-8888	t	altaf	nazmul	2024-02-07 15:22:04.064928+06	(23.7626808,90.3702093)	(23.7626784,90.3702063)	{}	f	0	sharif86r	t
2165	2024-02-07 15:41:39.037957+06	2	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-17-3886	t	altaf	nazmul	2024-02-07 15:56:48.541973+06	(23.762673,90.3702144)	(23.7626853,90.3702127)	{"(23.7626798,90.3702076)","(23.7626805,90.3702177)","(23.7626843,90.3702124)","(23.7626798,90.3702068)","(23.7626741,90.3702058)"}	f	0	siddiq2	t
2166	2024-02-07 16:03:05.438002+06	2	evening	{NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-17-3886	t	altaf	nazmul	2024-02-07 16:05:05.079601+06	(23.7626788,90.3702223)	(23.7626733,90.3702137)	{"(23.7626788,90.3702108)","(23.7626792,90.3702216)"}	f	0	siddiq2	t
\.


--
-- Name: broadcast_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.broadcast_notification_id_seq', 1, false);


--
-- Name: feedback_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.feedback_id_seq', 53, true);


--
-- Name: purchase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.purchase_id_seq', 69, true);


--
-- Name: requisition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.requisition_id_seq', 38, true);


--
-- Name: student_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.student_notification_id_seq', 1, false);


--
-- Name: upcoming_trip_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.upcoming_trip_id_seq', 2331, true);


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
-- Name: assignment assingment_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignment
    ADD CONSTRAINT assingment_id_pkey PRIMARY KEY (id);


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
-- Name: assignment assignment_bus_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignment
    ADD CONSTRAINT assignment_bus_fkey FOREIGN KEY (bus) REFERENCES public.bus(reg_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: assignment assignment_driver_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignment
    ADD CONSTRAINT assignment_driver_fkey FOREIGN KEY (driver) REFERENCES public.buet_staff(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: assignment assignment_helper_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignment
    ADD CONSTRAINT assignment_helper_fkey FOREIGN KEY (helper) REFERENCES public.buet_staff(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: assignment assignment_route_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignment
    ADD CONSTRAINT assignment_route_fkey1 FOREIGN KEY (route) REFERENCES public.route(id) ON UPDATE CASCADE ON DELETE CASCADE;


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
-- Name: ticket ticked_scanned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket
    ADD CONSTRAINT ticked_scanned_by_fkey FOREIGN KEY (scanned_by) REFERENCES public.bus_staff(id) NOT VALID;


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

