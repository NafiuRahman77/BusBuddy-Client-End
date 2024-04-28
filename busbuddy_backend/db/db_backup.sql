--
-- PostgreSQL database dump
--

-- Dumped from database version 15.6 (Debian 15.6-0+deb12u1)
-- Dumped by pg_dump version 15.6 (Debian 15.6-0+deb12u1)

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
-- Name: alloc_from_req(bigint, timestamp with time zone, character varying, character varying, character varying, character varying, character varying, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.alloc_from_req(IN id1 bigint, IN start_time1 timestamp with time zone, IN admin_id1 character varying, IN bus_id1 character varying, IN driver1 character varying, IN collector1 character varying, IN remarks1 character varying, IN payment1 integer, IN requestor1 character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
	allocation_id1 INTEGER;
BEGIN
    INSERT INTO allocation( start_timestamp, bus,    is_default, driver,    approved_by, helper) 
                    VALUES (start_time1,      bus_id1, false,      driver1, admin_id1,       collector1) RETURNING id INTO allocation_id1;
    UPDATE requisition SET timestamp = start_time1, approved_by = admin_id1, remarks = remarks1, is_approved=true, allocation_id=allocation_id1 WHERE id = id1;
	UPDATE buet_staff SET pending = pending + payment1 WHERE id = requestor1;

END;
$$;


ALTER PROCEDURE public.alloc_from_req(IN id1 bigint, IN start_time1 timestamp with time zone, IN admin_id1 character varying, IN bus_id1 character varying, IN driver1 character varying, IN collector1 character varying, IN remarks1 character varying, IN payment1 integer, IN requestor1 character varying) OWNER TO postgres;

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
-- Name: random_assignment(character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.random_assignment(IN admin_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    n INTEGER;
    drivers character varying[];
    helpers character varying[];
    buses character varying[];
    i INTEGER;
    sched_record RECORD;
BEGIN
    -- Count the number of rows in the 'schedule' table
    SELECT COUNT(*) INTO n FROM schedule;

    -- Populate the drivers array with n IDs from 'staff' table where role is 'driver'
    SELECT ARRAY(SELECT id FROM bus_staff WHERE role = 'driver' ORDER BY random()) INTO drivers LIMIT n;

    -- Populate the helpers array with n IDs from 'staff' table where role is 'helper'
    SELECT ARRAY(SELECT id FROM bus_staff WHERE role = 'collector' ORDER BY random()) INTO helpers LIMIT n;

    -- Populate the buses array with n IDs from 'bus' table where capacity is greater than or equal to 50
    SELECT ARRAY(SELECT reg_id FROM bus WHERE capacity >= 30 ORDER BY random()) INTO buses LIMIT n;

    i := 1;

    -- Iterate over all records in the 'schedule' table
    FOR sched_record IN SELECT * FROM schedule LOOP
        
            UPDATE schedule
            SET default_driver = drivers[i],
                default_helper = helpers[i],
                default_bus = buses[i]
            WHERE id = sched_record.id;
        i := i+1;
    END LOOP;
END;
$$;


ALTER PROCEDURE public.random_assignment(IN admin_id character varying) OWNER TO postgres;

--
-- Name: rotate_assignment(character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.rotate_assignment(IN admin_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    curr_schedule RECORD;
    next_schedule RECORD;
BEGIN
    -- Loop through each row in the 'schedule' table
	DELETE FROM assignment;
	INSERT INTO assignment (route, shift, driver, helper, bus, start_time)
	SELECT schedule.route, schedule.time_type, schedule.default_driver, schedule.default_helper, schedule.default_bus, current_timestamp
	FROM schedule;
	
    FOR curr_schedule IN SELECT * FROM schedule LOOP
        SELECT * INTO next_schedule FROM schedule WHERE route = (SELECT MIN(route) FROM schedule WHERE route > curr_schedule.route) AND time_type = curr_schedule.time_type;
        IF next_schedule IS NULL THEN
            SELECT * INTO next_schedule FROM schedule WHERE route = (SELECT MIN(route) FROM schedule) AND time_type = curr_schedule.time_type;
        END IF;

        UPDATE assignment
        SET driver = next_schedule.default_driver,
            helper = next_schedule.default_helper,
            bus = next_schedule.default_bus
        WHERE route = curr_schedule.route AND shift = curr_schedule.time_type;
    END LOOP;


    FOR curr_schedule IN SELECT * FROM assignment LOOP
        -- SELECT * INTO next_schedule FROM schedule WHERE route = (SELECT MIN(route) FROM schedule WHERE route > curr_schedule.route) AND time_type = curr_schedule.time_type;
        -- IF next_schedule IS NULL THEN
        --     SELECT * INTO next_schedule FROM schedule WHERE route = (SELECT MIN(route) FROM schedule) AND time_type = curr_schedule.time_type;
        -- END IF;

        UPDATE schedule
        SET default_driver = curr_schedule.driver,
            default_helper = curr_schedule.helper,
            default_bus = curr_schedule.bus        
        WHERE route = curr_schedule.route AND time_type = curr_schedule.shift;

    END LOOP;
	DELETE FROM assignment;
END;
$$;


ALTER PROCEDURE public.rotate_assignment(IN admin_id character varying) OWNER TO postgres;

--
-- Name: update_allocation(date, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.update_allocation(IN on_day date, IN admin_id character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    schedule_record RECORD;
BEGIN
    FOR schedule_record IN SELECT * FROM schedule LOOP
		CALL create_allocation(schedule_record.id, on_day, schedule_record.default_bus, schedule_record.default_driver, schedule_record.default_helper, admin_id);
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
    id integer NOT NULL,
    route character varying NOT NULL,
    bus character varying NOT NULL,
    driver character varying,
    helper character varying,
    valid boolean DEFAULT true NOT NULL,
    start_time timestamp with time zone NOT NULL,
    end_time timestamp with time zone,
    shift public.time_type NOT NULL
);


ALTER TABLE public.assignment OWNER TO postgres;

--
-- Name: assignment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.assignment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: broadcast_notification; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.broadcast_notification (
    id bigint NOT NULL,
    body text,
    "timestamp" timestamp with time zone NOT NULL,
    title text NOT NULL
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
    valid boolean DEFAULT true NOT NULL,
    pending integer DEFAULT 0,
    service boolean
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
    photo character varying,
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
    start_date timestamp with time zone,
    end_date timestamp with time zone,
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
    valid boolean DEFAULT true NOT NULL,
    pdate date
);


ALTER TABLE public.inventory OWNER TO postgres;

--
-- Name: notice; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notice (
    id integer NOT NULL,
    text character varying,
    date timestamp with time zone
);


ALTER TABLE public.notice OWNER TO postgres;

--
-- Name: notice_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notice_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notice_id_seq OWNER TO postgres;

--
-- Name: notice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notice_id_seq OWNED BY public.notice.id;


--
-- Name: personal_notification; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personal_notification (
    id bigint NOT NULL,
    body text,
    "timestamp" timestamp with time zone NOT NULL,
    title text NOT NULL,
    user_id character varying(32) NOT NULL
);


ALTER TABLE public.personal_notification OWNER TO postgres;

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
-- Name: repair; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.repair (
    id bigint NOT NULL,
    requestor character varying(64) NOT NULL,
    bus character varying(32) NOT NULL,
    parts text NOT NULL,
    request_des text,
    repair_des text,
    "timestamp" timestamp with time zone NOT NULL,
    is_repaired boolean DEFAULT false,
    missing character varying
);


ALTER TABLE public.repair OWNER TO postgres;

--
-- Name: repair_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.repair_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.repair_id_seq OWNER TO postgres;

--
-- Name: repair_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.repair_id_seq OWNED BY public.repair.id;


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
    valid boolean DEFAULT true NOT NULL,
    allocation_id bigint,
    remarks character varying,
    is_approved boolean
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
    travel_direction public.travel_direction NOT NULL,
    default_driver character varying,
    default_helper character varying,
    default_bus character varying
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

ALTER SEQUENCE public.student_notification_id_seq OWNED BY public.personal_notification.id;


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
    valid boolean DEFAULT true NOT NULL,
    time_window timestamp with time zone[]
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
-- Name: notice id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notice ALTER COLUMN id SET DEFAULT nextval('public.notice_id_seq'::regclass);


--
-- Name: personal_notification id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_notification ALTER COLUMN id SET DEFAULT nextval('public.student_notification_id_seq'::regclass);


--
-- Name: purchase id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase ALTER COLUMN id SET DEFAULT nextval('public.purchase_id_seq'::regclass);


--
-- Name: repair id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repair ALTER COLUMN id SET DEFAULT nextval('public.repair_id_seq'::regclass);


--
-- Name: requisition id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition ALTER COLUMN id SET DEFAULT nextval('public.requisition_id_seq'::regclass);


--
-- Name: student_feedback id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_feedback ALTER COLUMN id SET DEFAULT nextval('public.feedback_id_seq'::regclass);


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
4156	2024-04-30 23:30:00+06	6	evening	{"(41,\\"2024-04-30 23:30:00+06\\")","(42,\\"2024-04-30 23:46:00+06\\")","(43,\\"2024-04-30 23:48:00+06\\")","(44,\\"2024-04-30 23:50:00+06\\")","(45,\\"2024-04-30 23:52:00+06\\")","(46,\\"2024-04-30 23:54:00+06\\")","(47,\\"2024-04-30 23:56:00+06\\")","(48,\\"2024-04-30 23:58:00+06\\")","(49,\\"2024-04-30 00:00:00+06\\")","(70,\\"2024-04-30 00:02:00+06\\")"}	from_buet	Ba-83-8014	t	altaf78	nazmul	f	mahabhu	t
4157	2024-04-30 12:40:00+06	6	morning	{"(41,\\"2024-04-30 12:40:00+06\\")","(42,\\"2024-04-30 12:42:00+06\\")","(43,\\"2024-04-30 12:45:00+06\\")","(44,\\"2024-04-30 12:47:00+06\\")","(45,\\"2024-04-30 12:49:00+06\\")","(46,\\"2024-04-30 12:51:00+06\\")","(47,\\"2024-04-30 12:52:00+06\\")","(48,\\"2024-04-30 12:53:00+06\\")","(49,\\"2024-04-30 12:54:00+06\\")","(70,\\"2024-04-30 13:10:00+06\\")"}	to_buet	Ba-97-6734	t	shahid88	nazmul	f	azim990	t
4158	2024-04-30 19:40:00+06	6	afternoon	{"(41,\\"2024-04-30 19:40:00+06\\")","(42,\\"2024-04-30 19:56:00+06\\")","(43,\\"2024-04-30 19:58:00+06\\")","(44,\\"2024-04-30 20:00:00+06\\")","(45,\\"2024-04-30 20:02:00+06\\")","(46,\\"2024-04-30 20:04:00+06\\")","(47,\\"2024-04-30 20:06:00+06\\")","(48,\\"2024-04-30 20:08:00+06\\")","(49,\\"2024-04-30 20:10:00+06\\")","(70,\\"2024-04-30 20:12:00+06\\")"}	from_buet	Ba-36-1921	t	imranhashmi	nazmul	f	siam34	t
4159	2024-04-30 12:40:00+06	7	morning	{"(50,\\"2024-04-30 12:40:00+06\\")","(51,\\"2024-04-30 12:42:00+06\\")","(52,\\"2024-04-30 12:43:00+06\\")","(53,\\"2024-04-30 12:46:00+06\\")","(54,\\"2024-04-30 12:47:00+06\\")","(55,\\"2024-04-30 12:48:00+06\\")","(56,\\"2024-04-30 12:50:00+06\\")","(57,\\"2024-04-30 12:52:00+06\\")","(58,\\"2024-04-30 12:53:00+06\\")","(59,\\"2024-04-30 12:54:00+06\\")","(60,\\"2024-04-30 12:56:00+06\\")","(61,\\"2024-04-30 12:58:00+06\\")","(62,\\"2024-04-30 13:00:00+06\\")","(63,\\"2024-04-30 13:02:00+06\\")","(70,\\"2024-04-30 13:00:00+06\\")"}	to_buet	Ba-43-4286	t	nobiulnode	nazmul	f	mahmud64	t
4160	2024-04-30 19:40:00+06	7	afternoon	{"(50,\\"2024-04-30 19:40:00+06\\")","(51,\\"2024-04-30 19:48:00+06\\")","(52,\\"2024-04-30 19:50:00+06\\")","(53,\\"2024-04-30 19:52:00+06\\")","(54,\\"2024-04-30 19:54:00+06\\")","(55,\\"2024-04-30 19:56:00+06\\")","(56,\\"2024-04-30 19:58:00+06\\")","(57,\\"2024-04-30 20:00:00+06\\")","(58,\\"2024-04-30 20:02:00+06\\")","(59,\\"2024-04-30 20:04:00+06\\")","(60,\\"2024-04-30 20:06:00+06\\")","(61,\\"2024-04-30 20:08:00+06\\")","(62,\\"2024-04-30 20:10:00+06\\")","(63,\\"2024-04-30 20:12:00+06\\")","(70,\\"2024-04-30 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	polash	nazmul	f	zahir53	t
4161	2024-04-30 12:15:00+06	1	morning	{"(1,\\"2024-04-30 12:15:00+06\\")","(2,\\"2024-04-30 12:18:00+06\\")","(3,\\"2024-04-30 12:20:00+06\\")","(4,\\"2024-04-30 12:23:00+06\\")","(5,\\"2024-04-30 12:26:00+06\\")","(6,\\"2024-04-30 12:29:00+06\\")","(7,\\"2024-04-30 12:49:00+06\\")","(8,\\"2024-04-30 12:51:00+06\\")","(9,\\"2024-04-30 12:53:00+06\\")","(10,\\"2024-04-30 12:55:00+06\\")","(11,\\"2024-04-30 12:58:00+06\\")","(70,\\"2024-04-30 13:05:00+06\\")"}	to_buet	Ba-85-4722	t	monu67	nazmul	f	farid99	t
4162	2024-04-30 19:40:00+06	1	afternoon	{"(1,\\"2024-04-30 19:40:00+06\\")","(2,\\"2024-04-30 19:47:00+06\\")","(3,\\"2024-04-30 19:50:00+06\\")","(4,\\"2024-04-30 19:52:00+06\\")","(5,\\"2024-04-30 19:54:00+06\\")","(6,\\"2024-04-30 20:06:00+06\\")","(7,\\"2024-04-30 20:09:00+06\\")","(8,\\"2024-04-30 20:12:00+06\\")","(9,\\"2024-04-30 20:15:00+06\\")","(10,\\"2024-04-30 20:18:00+06\\")","(11,\\"2024-04-30 20:21:00+06\\")","(70,\\"2024-04-30 20:24:00+06\\")"}	from_buet	Ba-93-6087	t	nazrul6	nazmul	f	kk47	t
4163	2024-04-30 23:30:00+06	7	evening	{"(50,\\"2024-04-30 23:30:00+06\\")","(51,\\"2024-04-30 23:38:00+06\\")","(52,\\"2024-04-30 23:40:00+06\\")","(53,\\"2024-04-30 23:42:00+06\\")","(54,\\"2024-04-30 23:44:00+06\\")","(55,\\"2024-04-30 23:46:00+06\\")","(56,\\"2024-04-30 23:48:00+06\\")","(57,\\"2024-04-30 23:50:00+06\\")","(58,\\"2024-04-30 23:52:00+06\\")","(59,\\"2024-04-30 23:54:00+06\\")","(60,\\"2024-04-30 23:56:00+06\\")","(61,\\"2024-04-30 23:58:00+06\\")","(62,\\"2024-04-30 00:00:00+06\\")","(63,\\"2024-04-30 00:02:00+06\\")","(70,\\"2024-04-30 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	masud84	nazmul	f	reyazul	t
4164	2024-04-30 12:40:00+06	3	morning	{"(17,\\"2024-04-30 12:40:00+06\\")","(18,\\"2024-04-30 12:42:00+06\\")","(19,\\"2024-04-30 12:44:00+06\\")","(20,\\"2024-04-30 12:46:00+06\\")","(21,\\"2024-04-30 12:48:00+06\\")","(22,\\"2024-04-30 12:50:00+06\\")","(23,\\"2024-04-30 12:52:00+06\\")","(24,\\"2024-04-30 12:54:00+06\\")","(25,\\"2024-04-30 12:57:00+06\\")","(26,\\"2024-04-30 13:00:00+06\\")","(70,\\"2024-04-30 13:15:00+06\\")"}	to_buet	Ba-17-3886	t	rashed3	nazmul	f	abdulbari4	t
4165	2024-04-30 19:40:00+06	3	afternoon	{"(17,\\"2024-04-30 19:40:00+06\\")","(18,\\"2024-04-30 19:55:00+06\\")","(19,\\"2024-04-30 19:58:00+06\\")","(20,\\"2024-04-30 20:00:00+06\\")","(21,\\"2024-04-30 20:02:00+06\\")","(22,\\"2024-04-30 20:04:00+06\\")","(23,\\"2024-04-30 20:06:00+06\\")","(24,\\"2024-04-30 20:08:00+06\\")","(25,\\"2024-04-30 20:10:00+06\\")","(26,\\"2024-04-30 20:12:00+06\\")","(70,\\"2024-04-30 20:14:00+06\\")"}	from_buet	Ba-12-8888	t	felicitades35	nazmul	f	rishisunak45	t
4166	2024-04-30 12:40:00+06	4	morning	{"(27,\\"2024-04-30 12:40:00+06\\")","(28,\\"2024-04-30 12:42:00+06\\")","(29,\\"2024-04-30 12:44:00+06\\")","(30,\\"2024-04-30 12:46:00+06\\")","(31,\\"2024-04-30 12:50:00+06\\")","(32,\\"2024-04-30 12:52:00+06\\")","(33,\\"2024-04-30 12:54:00+06\\")","(34,\\"2024-04-30 12:58:00+06\\")","(35,\\"2024-04-30 13:00:00+06\\")","(70,\\"2024-04-30 13:10:00+06\\")"}	to_buet	Ba-69-8288	t	galloway67	nazmul	f	dariengap30	t
4167	2024-04-30 23:30:00+06	8	evening	{"(64,\\"2024-04-30 23:30:00+06\\")","(65,\\"2024-04-30 23:45:00+06\\")","(66,\\"2024-04-30 23:48:00+06\\")","(67,\\"2024-04-30 23:51:00+06\\")","(68,\\"2024-04-30 23:54:00+06\\")","(69,\\"2024-04-30 23:57:00+06\\")","(70,\\"2024-04-30 00:00:00+06\\")"}	from_buet	Ba-19-0569	t	marufmorshed	nazmul	f	jamal7898	t
4168	2024-04-30 12:55:00+06	2	morning	{"(12,\\"2024-04-30 12:55:00+06\\")","(13,\\"2024-04-30 12:57:00+06\\")","(14,\\"2024-04-30 12:59:00+06\\")","(15,\\"2024-04-30 13:01:00+06\\")","(16,\\"2024-04-30 13:03:00+06\\")","(70,\\"2024-04-30 13:15:00+06\\")"}	to_buet	Ba-22-4326	t	aminhaque	nazmul	f	refugee23	t
4169	2024-04-30 19:40:00+06	2	afternoon	{"(12,\\"2024-04-30 19:40:00+06\\")","(13,\\"2024-04-30 19:52:00+06\\")","(14,\\"2024-04-30 19:54:00+06\\")","(15,\\"2024-04-30 19:57:00+06\\")","(16,\\"2024-04-30 20:00:00+06\\")","(70,\\"2024-04-30 20:03:00+06\\")"}	from_buet	Ba-69-8288	t	kamaluddin	nazmul	f	rgbmbrt	t
4170	2024-04-30 23:30:00+06	2	evening	{"(12,\\"2024-04-30 23:30:00+06\\")","(13,\\"2024-04-30 23:42:00+06\\")","(14,\\"2024-04-30 23:45:00+06\\")","(15,\\"2024-04-30 23:48:00+06\\")","(16,\\"2024-04-30 23:51:00+06\\")","(70,\\"2024-04-30 23:54:00+06\\")"}	from_buet	Ba-86-1841	t	altaf	nazmul	f	shamsul54	t
4171	2024-04-30 23:30:00+06	4	evening	{"(27,\\"2024-04-30 23:30:00+06\\")","(28,\\"2024-04-30 23:40:00+06\\")","(29,\\"2024-04-30 23:42:00+06\\")","(30,\\"2024-04-30 23:44:00+06\\")","(31,\\"2024-04-30 23:46:00+06\\")","(32,\\"2024-04-30 23:48:00+06\\")","(33,\\"2024-04-30 23:50:00+06\\")","(34,\\"2024-04-30 23:52:00+06\\")","(35,\\"2024-04-30 23:54:00+06\\")","(70,\\"2024-04-30 23:56:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	f	germs23	t
4172	2024-04-30 12:30:00+06	5	morning	{"(36,\\"2024-04-30 12:30:00+06\\")","(37,\\"2024-04-30 12:33:00+06\\")","(38,\\"2024-04-30 12:40:00+06\\")","(39,\\"2024-04-30 12:45:00+06\\")","(40,\\"2024-04-30 12:50:00+06\\")","(70,\\"2024-04-30 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	nizam88	nazmul	f	rashid56	t
4173	2024-04-30 23:30:00+06	5	evening	{"(36,\\"2024-04-30 23:30:00+06\\")","(37,\\"2024-04-30 23:40:00+06\\")","(38,\\"2024-04-30 23:45:00+06\\")","(39,\\"2024-04-30 23:50:00+06\\")","(40,\\"2024-04-30 23:57:00+06\\")","(70,\\"2024-04-30 00:00:00+06\\")"}	from_buet	Ba-77-7044	t	galloway67	nazmul	f	ghioe22	t
4174	2024-04-30 19:40:00+06	5	afternoon	{"(36,\\"2024-04-30 19:40:00+06\\")","(37,\\"2024-04-30 19:50:00+06\\")","(38,\\"2024-04-30 19:55:00+06\\")","(39,\\"2024-04-30 20:00:00+06\\")","(40,\\"2024-04-30 20:07:00+06\\")","(70,\\"2024-04-30 20:10:00+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	f	mahbub777	t
4175	2024-04-30 23:30:00+06	1	evening	{"(1,\\"2024-04-30 23:30:00+06\\")","(2,\\"2024-04-30 23:37:00+06\\")","(3,\\"2024-04-30 23:40:00+06\\")","(4,\\"2024-04-30 23:42:00+06\\")","(5,\\"2024-04-30 23:44:00+06\\")","(6,\\"2024-04-30 23:56:00+06\\")","(7,\\"2024-04-30 23:59:00+06\\")","(8,\\"2024-04-30 00:02:00+06\\")","(9,\\"2024-04-30 00:05:00+06\\")","(10,\\"2024-04-30 00:08:00+06\\")","(11,\\"2024-04-30 00:11:00+06\\")","(70,\\"2024-04-30 00:14:00+06\\")"}	from_buet	Ba-48-5757	t	abdulkarim6	nazmul	f	siddiq2	t
4176	2024-04-30 12:10:00+06	8	morning	{"(64,\\"2024-04-30 12:10:00+06\\")","(65,\\"2024-04-30 12:13:00+06\\")","(66,\\"2024-04-30 12:18:00+06\\")","(67,\\"2024-04-30 12:20:00+06\\")","(68,\\"2024-04-30 12:22:00+06\\")","(69,\\"2024-04-30 12:25:00+06\\")","(70,\\"2024-04-30 12:40:00+06\\")"}	to_buet	Ba-17-2081	t	shafiqul	nazmul	f	sharif86r	t
4177	2024-04-30 19:40:00+06	8	afternoon	{"(64,\\"2024-04-30 19:40:00+06\\")","(65,\\"2024-04-30 19:55:00+06\\")","(66,\\"2024-04-30 19:58:00+06\\")","(67,\\"2024-04-30 20:01:00+06\\")","(68,\\"2024-04-30 20:04:00+06\\")","(69,\\"2024-04-30 20:07:00+06\\")","(70,\\"2024-04-30 20:10:00+06\\")"}	from_buet	Ba-71-7930	t	jahangir	nazmul	f	khairul	t
4178	2024-04-30 23:30:00+06	3	evening	{"(17,\\"2024-04-30 23:30:00+06\\")","(18,\\"2024-04-30 23:45:00+06\\")","(19,\\"2024-04-30 23:48:00+06\\")","(20,\\"2024-04-30 23:50:00+06\\")","(21,\\"2024-04-30 23:52:00+06\\")","(22,\\"2024-04-30 23:54:00+06\\")","(23,\\"2024-04-30 23:56:00+06\\")","(24,\\"2024-04-30 23:58:00+06\\")","(25,\\"2024-04-30 00:00:00+06\\")","(26,\\"2024-04-30 00:02:00+06\\")","(70,\\"2024-04-30 00:04:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81	t
4179	2024-04-30 19:40:00+06	4	afternoon	{"(27,\\"2024-04-30 19:40:00+06\\")","(28,\\"2024-04-30 19:50:00+06\\")","(29,\\"2024-04-30 19:52:00+06\\")","(30,\\"2024-04-30 19:54:00+06\\")","(31,\\"2024-04-30 19:56:00+06\\")","(32,\\"2024-04-30 19:58:00+06\\")","(33,\\"2024-04-30 20:00:00+06\\")","(34,\\"2024-04-30 20:02:00+06\\")","(35,\\"2024-04-30 20:04:00+06\\")","(70,\\"2024-04-30 20:06:00+06\\")"}	from_buet	BA-01-2345	t	ibrahim	nazmul	f	greece01	t
4180	2024-05-01 23:30:00+06	6	evening	{"(41,\\"2024-05-01 23:30:00+06\\")","(42,\\"2024-05-01 23:46:00+06\\")","(43,\\"2024-05-01 23:48:00+06\\")","(44,\\"2024-05-01 23:50:00+06\\")","(45,\\"2024-05-01 23:52:00+06\\")","(46,\\"2024-05-01 23:54:00+06\\")","(47,\\"2024-05-01 23:56:00+06\\")","(48,\\"2024-05-01 23:58:00+06\\")","(49,\\"2024-05-01 00:00:00+06\\")","(70,\\"2024-05-01 00:02:00+06\\")"}	from_buet	Ba-83-8014	t	altaf78	nazmul	f	mahabhu	t
4181	2024-05-01 12:40:00+06	6	morning	{"(41,\\"2024-05-01 12:40:00+06\\")","(42,\\"2024-05-01 12:42:00+06\\")","(43,\\"2024-05-01 12:45:00+06\\")","(44,\\"2024-05-01 12:47:00+06\\")","(45,\\"2024-05-01 12:49:00+06\\")","(46,\\"2024-05-01 12:51:00+06\\")","(47,\\"2024-05-01 12:52:00+06\\")","(48,\\"2024-05-01 12:53:00+06\\")","(49,\\"2024-05-01 12:54:00+06\\")","(70,\\"2024-05-01 13:10:00+06\\")"}	to_buet	Ba-97-6734	t	shahid88	nazmul	f	azim990	t
4182	2024-05-01 19:40:00+06	6	afternoon	{"(41,\\"2024-05-01 19:40:00+06\\")","(42,\\"2024-05-01 19:56:00+06\\")","(43,\\"2024-05-01 19:58:00+06\\")","(44,\\"2024-05-01 20:00:00+06\\")","(45,\\"2024-05-01 20:02:00+06\\")","(46,\\"2024-05-01 20:04:00+06\\")","(47,\\"2024-05-01 20:06:00+06\\")","(48,\\"2024-05-01 20:08:00+06\\")","(49,\\"2024-05-01 20:10:00+06\\")","(70,\\"2024-05-01 20:12:00+06\\")"}	from_buet	Ba-36-1921	t	imranhashmi	nazmul	f	siam34	t
4183	2024-05-01 12:40:00+06	7	morning	{"(50,\\"2024-05-01 12:40:00+06\\")","(51,\\"2024-05-01 12:42:00+06\\")","(52,\\"2024-05-01 12:43:00+06\\")","(53,\\"2024-05-01 12:46:00+06\\")","(54,\\"2024-05-01 12:47:00+06\\")","(55,\\"2024-05-01 12:48:00+06\\")","(56,\\"2024-05-01 12:50:00+06\\")","(57,\\"2024-05-01 12:52:00+06\\")","(58,\\"2024-05-01 12:53:00+06\\")","(59,\\"2024-05-01 12:54:00+06\\")","(60,\\"2024-05-01 12:56:00+06\\")","(61,\\"2024-05-01 12:58:00+06\\")","(62,\\"2024-05-01 13:00:00+06\\")","(63,\\"2024-05-01 13:02:00+06\\")","(70,\\"2024-05-01 13:00:00+06\\")"}	to_buet	Ba-43-4286	t	nobiulnode	nazmul	f	mahmud64	t
4184	2024-05-01 19:40:00+06	7	afternoon	{"(50,\\"2024-05-01 19:40:00+06\\")","(51,\\"2024-05-01 19:48:00+06\\")","(52,\\"2024-05-01 19:50:00+06\\")","(53,\\"2024-05-01 19:52:00+06\\")","(54,\\"2024-05-01 19:54:00+06\\")","(55,\\"2024-05-01 19:56:00+06\\")","(56,\\"2024-05-01 19:58:00+06\\")","(57,\\"2024-05-01 20:00:00+06\\")","(58,\\"2024-05-01 20:02:00+06\\")","(59,\\"2024-05-01 20:04:00+06\\")","(60,\\"2024-05-01 20:06:00+06\\")","(61,\\"2024-05-01 20:08:00+06\\")","(62,\\"2024-05-01 20:10:00+06\\")","(63,\\"2024-05-01 20:12:00+06\\")","(70,\\"2024-05-01 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	polash	nazmul	f	zahir53	t
4185	2024-05-01 12:15:00+06	1	morning	{"(1,\\"2024-05-01 12:15:00+06\\")","(2,\\"2024-05-01 12:18:00+06\\")","(3,\\"2024-05-01 12:20:00+06\\")","(4,\\"2024-05-01 12:23:00+06\\")","(5,\\"2024-05-01 12:26:00+06\\")","(6,\\"2024-05-01 12:29:00+06\\")","(7,\\"2024-05-01 12:49:00+06\\")","(8,\\"2024-05-01 12:51:00+06\\")","(9,\\"2024-05-01 12:53:00+06\\")","(10,\\"2024-05-01 12:55:00+06\\")","(11,\\"2024-05-01 12:58:00+06\\")","(70,\\"2024-05-01 13:05:00+06\\")"}	to_buet	Ba-85-4722	t	monu67	nazmul	f	farid99	t
4186	2024-05-01 19:40:00+06	1	afternoon	{"(1,\\"2024-05-01 19:40:00+06\\")","(2,\\"2024-05-01 19:47:00+06\\")","(3,\\"2024-05-01 19:50:00+06\\")","(4,\\"2024-05-01 19:52:00+06\\")","(5,\\"2024-05-01 19:54:00+06\\")","(6,\\"2024-05-01 20:06:00+06\\")","(7,\\"2024-05-01 20:09:00+06\\")","(8,\\"2024-05-01 20:12:00+06\\")","(9,\\"2024-05-01 20:15:00+06\\")","(10,\\"2024-05-01 20:18:00+06\\")","(11,\\"2024-05-01 20:21:00+06\\")","(70,\\"2024-05-01 20:24:00+06\\")"}	from_buet	Ba-93-6087	t	nazrul6	nazmul	f	kk47	t
4187	2024-05-01 23:30:00+06	7	evening	{"(50,\\"2024-05-01 23:30:00+06\\")","(51,\\"2024-05-01 23:38:00+06\\")","(52,\\"2024-05-01 23:40:00+06\\")","(53,\\"2024-05-01 23:42:00+06\\")","(54,\\"2024-05-01 23:44:00+06\\")","(55,\\"2024-05-01 23:46:00+06\\")","(56,\\"2024-05-01 23:48:00+06\\")","(57,\\"2024-05-01 23:50:00+06\\")","(58,\\"2024-05-01 23:52:00+06\\")","(59,\\"2024-05-01 23:54:00+06\\")","(60,\\"2024-05-01 23:56:00+06\\")","(61,\\"2024-05-01 23:58:00+06\\")","(62,\\"2024-05-01 00:00:00+06\\")","(63,\\"2024-05-01 00:02:00+06\\")","(70,\\"2024-05-01 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	masud84	nazmul	f	reyazul	t
4188	2024-05-01 12:40:00+06	3	morning	{"(17,\\"2024-05-01 12:40:00+06\\")","(18,\\"2024-05-01 12:42:00+06\\")","(19,\\"2024-05-01 12:44:00+06\\")","(20,\\"2024-05-01 12:46:00+06\\")","(21,\\"2024-05-01 12:48:00+06\\")","(22,\\"2024-05-01 12:50:00+06\\")","(23,\\"2024-05-01 12:52:00+06\\")","(24,\\"2024-05-01 12:54:00+06\\")","(25,\\"2024-05-01 12:57:00+06\\")","(26,\\"2024-05-01 13:00:00+06\\")","(70,\\"2024-05-01 13:15:00+06\\")"}	to_buet	Ba-17-3886	t	rashed3	nazmul	f	abdulbari4	t
4189	2024-05-01 19:40:00+06	3	afternoon	{"(17,\\"2024-05-01 19:40:00+06\\")","(18,\\"2024-05-01 19:55:00+06\\")","(19,\\"2024-05-01 19:58:00+06\\")","(20,\\"2024-05-01 20:00:00+06\\")","(21,\\"2024-05-01 20:02:00+06\\")","(22,\\"2024-05-01 20:04:00+06\\")","(23,\\"2024-05-01 20:06:00+06\\")","(24,\\"2024-05-01 20:08:00+06\\")","(25,\\"2024-05-01 20:10:00+06\\")","(26,\\"2024-05-01 20:12:00+06\\")","(70,\\"2024-05-01 20:14:00+06\\")"}	from_buet	Ba-12-8888	t	felicitades35	nazmul	f	rishisunak45	t
4190	2024-05-01 12:40:00+06	4	morning	{"(27,\\"2024-05-01 12:40:00+06\\")","(28,\\"2024-05-01 12:42:00+06\\")","(29,\\"2024-05-01 12:44:00+06\\")","(30,\\"2024-05-01 12:46:00+06\\")","(31,\\"2024-05-01 12:50:00+06\\")","(32,\\"2024-05-01 12:52:00+06\\")","(33,\\"2024-05-01 12:54:00+06\\")","(34,\\"2024-05-01 12:58:00+06\\")","(35,\\"2024-05-01 13:00:00+06\\")","(70,\\"2024-05-01 13:10:00+06\\")"}	to_buet	Ba-69-8288	t	galloway67	nazmul	f	dariengap30	t
4191	2024-05-01 23:30:00+06	8	evening	{"(64,\\"2024-05-01 23:30:00+06\\")","(65,\\"2024-05-01 23:45:00+06\\")","(66,\\"2024-05-01 23:48:00+06\\")","(67,\\"2024-05-01 23:51:00+06\\")","(68,\\"2024-05-01 23:54:00+06\\")","(69,\\"2024-05-01 23:57:00+06\\")","(70,\\"2024-05-01 00:00:00+06\\")"}	from_buet	Ba-19-0569	t	marufmorshed	nazmul	f	jamal7898	t
4192	2024-05-01 12:55:00+06	2	morning	{"(12,\\"2024-05-01 12:55:00+06\\")","(13,\\"2024-05-01 12:57:00+06\\")","(14,\\"2024-05-01 12:59:00+06\\")","(15,\\"2024-05-01 13:01:00+06\\")","(16,\\"2024-05-01 13:03:00+06\\")","(70,\\"2024-05-01 13:15:00+06\\")"}	to_buet	Ba-22-4326	t	aminhaque	nazmul	f	refugee23	t
4193	2024-05-01 19:40:00+06	2	afternoon	{"(12,\\"2024-05-01 19:40:00+06\\")","(13,\\"2024-05-01 19:52:00+06\\")","(14,\\"2024-05-01 19:54:00+06\\")","(15,\\"2024-05-01 19:57:00+06\\")","(16,\\"2024-05-01 20:00:00+06\\")","(70,\\"2024-05-01 20:03:00+06\\")"}	from_buet	Ba-69-8288	t	kamaluddin	nazmul	f	rgbmbrt	t
4194	2024-05-01 23:30:00+06	2	evening	{"(12,\\"2024-05-01 23:30:00+06\\")","(13,\\"2024-05-01 23:42:00+06\\")","(14,\\"2024-05-01 23:45:00+06\\")","(15,\\"2024-05-01 23:48:00+06\\")","(16,\\"2024-05-01 23:51:00+06\\")","(70,\\"2024-05-01 23:54:00+06\\")"}	from_buet	Ba-86-1841	t	altaf	nazmul	f	shamsul54	t
4195	2024-05-01 23:30:00+06	4	evening	{"(27,\\"2024-05-01 23:30:00+06\\")","(28,\\"2024-05-01 23:40:00+06\\")","(29,\\"2024-05-01 23:42:00+06\\")","(30,\\"2024-05-01 23:44:00+06\\")","(31,\\"2024-05-01 23:46:00+06\\")","(32,\\"2024-05-01 23:48:00+06\\")","(33,\\"2024-05-01 23:50:00+06\\")","(34,\\"2024-05-01 23:52:00+06\\")","(35,\\"2024-05-01 23:54:00+06\\")","(70,\\"2024-05-01 23:56:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	f	germs23	t
4196	2024-05-01 12:30:00+06	5	morning	{"(36,\\"2024-05-01 12:30:00+06\\")","(37,\\"2024-05-01 12:33:00+06\\")","(38,\\"2024-05-01 12:40:00+06\\")","(39,\\"2024-05-01 12:45:00+06\\")","(40,\\"2024-05-01 12:50:00+06\\")","(70,\\"2024-05-01 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	nizam88	nazmul	f	rashid56	t
4197	2024-05-01 23:30:00+06	5	evening	{"(36,\\"2024-05-01 23:30:00+06\\")","(37,\\"2024-05-01 23:40:00+06\\")","(38,\\"2024-05-01 23:45:00+06\\")","(39,\\"2024-05-01 23:50:00+06\\")","(40,\\"2024-05-01 23:57:00+06\\")","(70,\\"2024-05-01 00:00:00+06\\")"}	from_buet	Ba-77-7044	t	galloway67	nazmul	f	ghioe22	t
4198	2024-05-01 19:40:00+06	5	afternoon	{"(36,\\"2024-05-01 19:40:00+06\\")","(37,\\"2024-05-01 19:50:00+06\\")","(38,\\"2024-05-01 19:55:00+06\\")","(39,\\"2024-05-01 20:00:00+06\\")","(40,\\"2024-05-01 20:07:00+06\\")","(70,\\"2024-05-01 20:10:00+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	f	mahbub777	t
4199	2024-05-01 23:30:00+06	1	evening	{"(1,\\"2024-05-01 23:30:00+06\\")","(2,\\"2024-05-01 23:37:00+06\\")","(3,\\"2024-05-01 23:40:00+06\\")","(4,\\"2024-05-01 23:42:00+06\\")","(5,\\"2024-05-01 23:44:00+06\\")","(6,\\"2024-05-01 23:56:00+06\\")","(7,\\"2024-05-01 23:59:00+06\\")","(8,\\"2024-05-01 00:02:00+06\\")","(9,\\"2024-05-01 00:05:00+06\\")","(10,\\"2024-05-01 00:08:00+06\\")","(11,\\"2024-05-01 00:11:00+06\\")","(70,\\"2024-05-01 00:14:00+06\\")"}	from_buet	Ba-48-5757	t	abdulkarim6	nazmul	f	siddiq2	t
4200	2024-05-01 12:10:00+06	8	morning	{"(64,\\"2024-05-01 12:10:00+06\\")","(65,\\"2024-05-01 12:13:00+06\\")","(66,\\"2024-05-01 12:18:00+06\\")","(67,\\"2024-05-01 12:20:00+06\\")","(68,\\"2024-05-01 12:22:00+06\\")","(69,\\"2024-05-01 12:25:00+06\\")","(70,\\"2024-05-01 12:40:00+06\\")"}	to_buet	Ba-17-2081	t	shafiqul	nazmul	f	sharif86r	t
4201	2024-05-01 19:40:00+06	8	afternoon	{"(64,\\"2024-05-01 19:40:00+06\\")","(65,\\"2024-05-01 19:55:00+06\\")","(66,\\"2024-05-01 19:58:00+06\\")","(67,\\"2024-05-01 20:01:00+06\\")","(68,\\"2024-05-01 20:04:00+06\\")","(69,\\"2024-05-01 20:07:00+06\\")","(70,\\"2024-05-01 20:10:00+06\\")"}	from_buet	Ba-71-7930	t	jahangir	nazmul	f	khairul	t
4202	2024-05-01 23:30:00+06	3	evening	{"(17,\\"2024-05-01 23:30:00+06\\")","(18,\\"2024-05-01 23:45:00+06\\")","(19,\\"2024-05-01 23:48:00+06\\")","(20,\\"2024-05-01 23:50:00+06\\")","(21,\\"2024-05-01 23:52:00+06\\")","(22,\\"2024-05-01 23:54:00+06\\")","(23,\\"2024-05-01 23:56:00+06\\")","(24,\\"2024-05-01 23:58:00+06\\")","(25,\\"2024-05-01 00:00:00+06\\")","(26,\\"2024-05-01 00:02:00+06\\")","(70,\\"2024-05-01 00:04:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81	t
4203	2024-05-01 19:40:00+06	4	afternoon	{"(27,\\"2024-05-01 19:40:00+06\\")","(28,\\"2024-05-01 19:50:00+06\\")","(29,\\"2024-05-01 19:52:00+06\\")","(30,\\"2024-05-01 19:54:00+06\\")","(31,\\"2024-05-01 19:56:00+06\\")","(32,\\"2024-05-01 19:58:00+06\\")","(33,\\"2024-05-01 20:00:00+06\\")","(34,\\"2024-05-01 20:02:00+06\\")","(35,\\"2024-05-01 20:04:00+06\\")","(70,\\"2024-05-01 20:06:00+06\\")"}	from_buet	BA-01-2345	t	ibrahim	nazmul	f	greece01	t
4204	2024-05-02 23:30:00+06	6	evening	{"(41,\\"2024-05-02 23:30:00+06\\")","(42,\\"2024-05-02 23:46:00+06\\")","(43,\\"2024-05-02 23:48:00+06\\")","(44,\\"2024-05-02 23:50:00+06\\")","(45,\\"2024-05-02 23:52:00+06\\")","(46,\\"2024-05-02 23:54:00+06\\")","(47,\\"2024-05-02 23:56:00+06\\")","(48,\\"2024-05-02 23:58:00+06\\")","(49,\\"2024-05-02 00:00:00+06\\")","(70,\\"2024-05-02 00:02:00+06\\")"}	from_buet	Ba-83-8014	t	altaf78	nazmul	f	mahabhu	t
4205	2024-05-02 12:40:00+06	6	morning	{"(41,\\"2024-05-02 12:40:00+06\\")","(42,\\"2024-05-02 12:42:00+06\\")","(43,\\"2024-05-02 12:45:00+06\\")","(44,\\"2024-05-02 12:47:00+06\\")","(45,\\"2024-05-02 12:49:00+06\\")","(46,\\"2024-05-02 12:51:00+06\\")","(47,\\"2024-05-02 12:52:00+06\\")","(48,\\"2024-05-02 12:53:00+06\\")","(49,\\"2024-05-02 12:54:00+06\\")","(70,\\"2024-05-02 13:10:00+06\\")"}	to_buet	Ba-97-6734	t	shahid88	nazmul	f	azim990	t
4206	2024-05-02 19:40:00+06	6	afternoon	{"(41,\\"2024-05-02 19:40:00+06\\")","(42,\\"2024-05-02 19:56:00+06\\")","(43,\\"2024-05-02 19:58:00+06\\")","(44,\\"2024-05-02 20:00:00+06\\")","(45,\\"2024-05-02 20:02:00+06\\")","(46,\\"2024-05-02 20:04:00+06\\")","(47,\\"2024-05-02 20:06:00+06\\")","(48,\\"2024-05-02 20:08:00+06\\")","(49,\\"2024-05-02 20:10:00+06\\")","(70,\\"2024-05-02 20:12:00+06\\")"}	from_buet	Ba-36-1921	t	imranhashmi	nazmul	f	siam34	t
4207	2024-05-02 12:40:00+06	7	morning	{"(50,\\"2024-05-02 12:40:00+06\\")","(51,\\"2024-05-02 12:42:00+06\\")","(52,\\"2024-05-02 12:43:00+06\\")","(53,\\"2024-05-02 12:46:00+06\\")","(54,\\"2024-05-02 12:47:00+06\\")","(55,\\"2024-05-02 12:48:00+06\\")","(56,\\"2024-05-02 12:50:00+06\\")","(57,\\"2024-05-02 12:52:00+06\\")","(58,\\"2024-05-02 12:53:00+06\\")","(59,\\"2024-05-02 12:54:00+06\\")","(60,\\"2024-05-02 12:56:00+06\\")","(61,\\"2024-05-02 12:58:00+06\\")","(62,\\"2024-05-02 13:00:00+06\\")","(63,\\"2024-05-02 13:02:00+06\\")","(70,\\"2024-05-02 13:00:00+06\\")"}	to_buet	Ba-43-4286	t	nobiulnode	nazmul	f	mahmud64	t
4208	2024-05-02 19:40:00+06	7	afternoon	{"(50,\\"2024-05-02 19:40:00+06\\")","(51,\\"2024-05-02 19:48:00+06\\")","(52,\\"2024-05-02 19:50:00+06\\")","(53,\\"2024-05-02 19:52:00+06\\")","(54,\\"2024-05-02 19:54:00+06\\")","(55,\\"2024-05-02 19:56:00+06\\")","(56,\\"2024-05-02 19:58:00+06\\")","(57,\\"2024-05-02 20:00:00+06\\")","(58,\\"2024-05-02 20:02:00+06\\")","(59,\\"2024-05-02 20:04:00+06\\")","(60,\\"2024-05-02 20:06:00+06\\")","(61,\\"2024-05-02 20:08:00+06\\")","(62,\\"2024-05-02 20:10:00+06\\")","(63,\\"2024-05-02 20:12:00+06\\")","(70,\\"2024-05-02 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	polash	nazmul	f	zahir53	t
4209	2024-05-02 12:15:00+06	1	morning	{"(1,\\"2024-05-02 12:15:00+06\\")","(2,\\"2024-05-02 12:18:00+06\\")","(3,\\"2024-05-02 12:20:00+06\\")","(4,\\"2024-05-02 12:23:00+06\\")","(5,\\"2024-05-02 12:26:00+06\\")","(6,\\"2024-05-02 12:29:00+06\\")","(7,\\"2024-05-02 12:49:00+06\\")","(8,\\"2024-05-02 12:51:00+06\\")","(9,\\"2024-05-02 12:53:00+06\\")","(10,\\"2024-05-02 12:55:00+06\\")","(11,\\"2024-05-02 12:58:00+06\\")","(70,\\"2024-05-02 13:05:00+06\\")"}	to_buet	Ba-85-4722	t	monu67	nazmul	f	farid99	t
4210	2024-05-02 19:40:00+06	1	afternoon	{"(1,\\"2024-05-02 19:40:00+06\\")","(2,\\"2024-05-02 19:47:00+06\\")","(3,\\"2024-05-02 19:50:00+06\\")","(4,\\"2024-05-02 19:52:00+06\\")","(5,\\"2024-05-02 19:54:00+06\\")","(6,\\"2024-05-02 20:06:00+06\\")","(7,\\"2024-05-02 20:09:00+06\\")","(8,\\"2024-05-02 20:12:00+06\\")","(9,\\"2024-05-02 20:15:00+06\\")","(10,\\"2024-05-02 20:18:00+06\\")","(11,\\"2024-05-02 20:21:00+06\\")","(70,\\"2024-05-02 20:24:00+06\\")"}	from_buet	Ba-93-6087	t	nazrul6	nazmul	f	kk47	t
4211	2024-05-02 23:30:00+06	7	evening	{"(50,\\"2024-05-02 23:30:00+06\\")","(51,\\"2024-05-02 23:38:00+06\\")","(52,\\"2024-05-02 23:40:00+06\\")","(53,\\"2024-05-02 23:42:00+06\\")","(54,\\"2024-05-02 23:44:00+06\\")","(55,\\"2024-05-02 23:46:00+06\\")","(56,\\"2024-05-02 23:48:00+06\\")","(57,\\"2024-05-02 23:50:00+06\\")","(58,\\"2024-05-02 23:52:00+06\\")","(59,\\"2024-05-02 23:54:00+06\\")","(60,\\"2024-05-02 23:56:00+06\\")","(61,\\"2024-05-02 23:58:00+06\\")","(62,\\"2024-05-02 00:00:00+06\\")","(63,\\"2024-05-02 00:02:00+06\\")","(70,\\"2024-05-02 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	masud84	nazmul	f	reyazul	t
4212	2024-05-02 12:40:00+06	3	morning	{"(17,\\"2024-05-02 12:40:00+06\\")","(18,\\"2024-05-02 12:42:00+06\\")","(19,\\"2024-05-02 12:44:00+06\\")","(20,\\"2024-05-02 12:46:00+06\\")","(21,\\"2024-05-02 12:48:00+06\\")","(22,\\"2024-05-02 12:50:00+06\\")","(23,\\"2024-05-02 12:52:00+06\\")","(24,\\"2024-05-02 12:54:00+06\\")","(25,\\"2024-05-02 12:57:00+06\\")","(26,\\"2024-05-02 13:00:00+06\\")","(70,\\"2024-05-02 13:15:00+06\\")"}	to_buet	Ba-17-3886	t	rashed3	nazmul	f	abdulbari4	t
4213	2024-05-02 19:40:00+06	3	afternoon	{"(17,\\"2024-05-02 19:40:00+06\\")","(18,\\"2024-05-02 19:55:00+06\\")","(19,\\"2024-05-02 19:58:00+06\\")","(20,\\"2024-05-02 20:00:00+06\\")","(21,\\"2024-05-02 20:02:00+06\\")","(22,\\"2024-05-02 20:04:00+06\\")","(23,\\"2024-05-02 20:06:00+06\\")","(24,\\"2024-05-02 20:08:00+06\\")","(25,\\"2024-05-02 20:10:00+06\\")","(26,\\"2024-05-02 20:12:00+06\\")","(70,\\"2024-05-02 20:14:00+06\\")"}	from_buet	Ba-12-8888	t	felicitades35	nazmul	f	rishisunak45	t
4214	2024-05-02 12:40:00+06	4	morning	{"(27,\\"2024-05-02 12:40:00+06\\")","(28,\\"2024-05-02 12:42:00+06\\")","(29,\\"2024-05-02 12:44:00+06\\")","(30,\\"2024-05-02 12:46:00+06\\")","(31,\\"2024-05-02 12:50:00+06\\")","(32,\\"2024-05-02 12:52:00+06\\")","(33,\\"2024-05-02 12:54:00+06\\")","(34,\\"2024-05-02 12:58:00+06\\")","(35,\\"2024-05-02 13:00:00+06\\")","(70,\\"2024-05-02 13:10:00+06\\")"}	to_buet	Ba-69-8288	t	galloway67	nazmul	f	dariengap30	t
4215	2024-05-02 23:30:00+06	8	evening	{"(64,\\"2024-05-02 23:30:00+06\\")","(65,\\"2024-05-02 23:45:00+06\\")","(66,\\"2024-05-02 23:48:00+06\\")","(67,\\"2024-05-02 23:51:00+06\\")","(68,\\"2024-05-02 23:54:00+06\\")","(69,\\"2024-05-02 23:57:00+06\\")","(70,\\"2024-05-02 00:00:00+06\\")"}	from_buet	Ba-19-0569	t	marufmorshed	nazmul	f	jamal7898	t
4216	2024-05-02 12:55:00+06	2	morning	{"(12,\\"2024-05-02 12:55:00+06\\")","(13,\\"2024-05-02 12:57:00+06\\")","(14,\\"2024-05-02 12:59:00+06\\")","(15,\\"2024-05-02 13:01:00+06\\")","(16,\\"2024-05-02 13:03:00+06\\")","(70,\\"2024-05-02 13:15:00+06\\")"}	to_buet	Ba-22-4326	t	aminhaque	nazmul	f	refugee23	t
4217	2024-05-02 19:40:00+06	2	afternoon	{"(12,\\"2024-05-02 19:40:00+06\\")","(13,\\"2024-05-02 19:52:00+06\\")","(14,\\"2024-05-02 19:54:00+06\\")","(15,\\"2024-05-02 19:57:00+06\\")","(16,\\"2024-05-02 20:00:00+06\\")","(70,\\"2024-05-02 20:03:00+06\\")"}	from_buet	Ba-69-8288	t	kamaluddin	nazmul	f	rgbmbrt	t
4218	2024-05-02 23:30:00+06	2	evening	{"(12,\\"2024-05-02 23:30:00+06\\")","(13,\\"2024-05-02 23:42:00+06\\")","(14,\\"2024-05-02 23:45:00+06\\")","(15,\\"2024-05-02 23:48:00+06\\")","(16,\\"2024-05-02 23:51:00+06\\")","(70,\\"2024-05-02 23:54:00+06\\")"}	from_buet	Ba-86-1841	t	altaf	nazmul	f	shamsul54	t
4219	2024-05-02 23:30:00+06	4	evening	{"(27,\\"2024-05-02 23:30:00+06\\")","(28,\\"2024-05-02 23:40:00+06\\")","(29,\\"2024-05-02 23:42:00+06\\")","(30,\\"2024-05-02 23:44:00+06\\")","(31,\\"2024-05-02 23:46:00+06\\")","(32,\\"2024-05-02 23:48:00+06\\")","(33,\\"2024-05-02 23:50:00+06\\")","(34,\\"2024-05-02 23:52:00+06\\")","(35,\\"2024-05-02 23:54:00+06\\")","(70,\\"2024-05-02 23:56:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	f	germs23	t
4220	2024-05-02 12:30:00+06	5	morning	{"(36,\\"2024-05-02 12:30:00+06\\")","(37,\\"2024-05-02 12:33:00+06\\")","(38,\\"2024-05-02 12:40:00+06\\")","(39,\\"2024-05-02 12:45:00+06\\")","(40,\\"2024-05-02 12:50:00+06\\")","(70,\\"2024-05-02 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	nizam88	nazmul	f	rashid56	t
4221	2024-05-02 23:30:00+06	5	evening	{"(36,\\"2024-05-02 23:30:00+06\\")","(37,\\"2024-05-02 23:40:00+06\\")","(38,\\"2024-05-02 23:45:00+06\\")","(39,\\"2024-05-02 23:50:00+06\\")","(40,\\"2024-05-02 23:57:00+06\\")","(70,\\"2024-05-02 00:00:00+06\\")"}	from_buet	Ba-77-7044	t	galloway67	nazmul	f	ghioe22	t
4222	2024-05-02 19:40:00+06	5	afternoon	{"(36,\\"2024-05-02 19:40:00+06\\")","(37,\\"2024-05-02 19:50:00+06\\")","(38,\\"2024-05-02 19:55:00+06\\")","(39,\\"2024-05-02 20:00:00+06\\")","(40,\\"2024-05-02 20:07:00+06\\")","(70,\\"2024-05-02 20:10:00+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	f	mahbub777	t
4223	2024-05-02 23:30:00+06	1	evening	{"(1,\\"2024-05-02 23:30:00+06\\")","(2,\\"2024-05-02 23:37:00+06\\")","(3,\\"2024-05-02 23:40:00+06\\")","(4,\\"2024-05-02 23:42:00+06\\")","(5,\\"2024-05-02 23:44:00+06\\")","(6,\\"2024-05-02 23:56:00+06\\")","(7,\\"2024-05-02 23:59:00+06\\")","(8,\\"2024-05-02 00:02:00+06\\")","(9,\\"2024-05-02 00:05:00+06\\")","(10,\\"2024-05-02 00:08:00+06\\")","(11,\\"2024-05-02 00:11:00+06\\")","(70,\\"2024-05-02 00:14:00+06\\")"}	from_buet	Ba-48-5757	t	abdulkarim6	nazmul	f	siddiq2	t
4224	2024-05-02 12:10:00+06	8	morning	{"(64,\\"2024-05-02 12:10:00+06\\")","(65,\\"2024-05-02 12:13:00+06\\")","(66,\\"2024-05-02 12:18:00+06\\")","(67,\\"2024-05-02 12:20:00+06\\")","(68,\\"2024-05-02 12:22:00+06\\")","(69,\\"2024-05-02 12:25:00+06\\")","(70,\\"2024-05-02 12:40:00+06\\")"}	to_buet	Ba-17-2081	t	shafiqul	nazmul	f	sharif86r	t
4225	2024-05-02 19:40:00+06	8	afternoon	{"(64,\\"2024-05-02 19:40:00+06\\")","(65,\\"2024-05-02 19:55:00+06\\")","(66,\\"2024-05-02 19:58:00+06\\")","(67,\\"2024-05-02 20:01:00+06\\")","(68,\\"2024-05-02 20:04:00+06\\")","(69,\\"2024-05-02 20:07:00+06\\")","(70,\\"2024-05-02 20:10:00+06\\")"}	from_buet	Ba-71-7930	t	jahangir	nazmul	f	khairul	t
4226	2024-05-02 23:30:00+06	3	evening	{"(17,\\"2024-05-02 23:30:00+06\\")","(18,\\"2024-05-02 23:45:00+06\\")","(19,\\"2024-05-02 23:48:00+06\\")","(20,\\"2024-05-02 23:50:00+06\\")","(21,\\"2024-05-02 23:52:00+06\\")","(22,\\"2024-05-02 23:54:00+06\\")","(23,\\"2024-05-02 23:56:00+06\\")","(24,\\"2024-05-02 23:58:00+06\\")","(25,\\"2024-05-02 00:00:00+06\\")","(26,\\"2024-05-02 00:02:00+06\\")","(70,\\"2024-05-02 00:04:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81	t
4227	2024-05-02 19:40:00+06	4	afternoon	{"(27,\\"2024-05-02 19:40:00+06\\")","(28,\\"2024-05-02 19:50:00+06\\")","(29,\\"2024-05-02 19:52:00+06\\")","(30,\\"2024-05-02 19:54:00+06\\")","(31,\\"2024-05-02 19:56:00+06\\")","(32,\\"2024-05-02 19:58:00+06\\")","(33,\\"2024-05-02 20:00:00+06\\")","(34,\\"2024-05-02 20:02:00+06\\")","(35,\\"2024-05-02 20:04:00+06\\")","(70,\\"2024-05-02 20:06:00+06\\")"}	from_buet	BA-01-2345	t	ibrahim	nazmul	f	greece01	t
4228	2024-05-03 23:30:00+06	6	evening	{"(41,\\"2024-05-03 23:30:00+06\\")","(42,\\"2024-05-03 23:46:00+06\\")","(43,\\"2024-05-03 23:48:00+06\\")","(44,\\"2024-05-03 23:50:00+06\\")","(45,\\"2024-05-03 23:52:00+06\\")","(46,\\"2024-05-03 23:54:00+06\\")","(47,\\"2024-05-03 23:56:00+06\\")","(48,\\"2024-05-03 23:58:00+06\\")","(49,\\"2024-05-03 00:00:00+06\\")","(70,\\"2024-05-03 00:02:00+06\\")"}	from_buet	Ba-83-8014	t	altaf78	nazmul	f	mahabhu	t
4229	2024-05-03 12:40:00+06	6	morning	{"(41,\\"2024-05-03 12:40:00+06\\")","(42,\\"2024-05-03 12:42:00+06\\")","(43,\\"2024-05-03 12:45:00+06\\")","(44,\\"2024-05-03 12:47:00+06\\")","(45,\\"2024-05-03 12:49:00+06\\")","(46,\\"2024-05-03 12:51:00+06\\")","(47,\\"2024-05-03 12:52:00+06\\")","(48,\\"2024-05-03 12:53:00+06\\")","(49,\\"2024-05-03 12:54:00+06\\")","(70,\\"2024-05-03 13:10:00+06\\")"}	to_buet	Ba-97-6734	t	shahid88	nazmul	f	azim990	t
4230	2024-05-03 19:40:00+06	6	afternoon	{"(41,\\"2024-05-03 19:40:00+06\\")","(42,\\"2024-05-03 19:56:00+06\\")","(43,\\"2024-05-03 19:58:00+06\\")","(44,\\"2024-05-03 20:00:00+06\\")","(45,\\"2024-05-03 20:02:00+06\\")","(46,\\"2024-05-03 20:04:00+06\\")","(47,\\"2024-05-03 20:06:00+06\\")","(48,\\"2024-05-03 20:08:00+06\\")","(49,\\"2024-05-03 20:10:00+06\\")","(70,\\"2024-05-03 20:12:00+06\\")"}	from_buet	Ba-36-1921	t	imranhashmi	nazmul	f	siam34	t
4231	2024-05-03 12:40:00+06	7	morning	{"(50,\\"2024-05-03 12:40:00+06\\")","(51,\\"2024-05-03 12:42:00+06\\")","(52,\\"2024-05-03 12:43:00+06\\")","(53,\\"2024-05-03 12:46:00+06\\")","(54,\\"2024-05-03 12:47:00+06\\")","(55,\\"2024-05-03 12:48:00+06\\")","(56,\\"2024-05-03 12:50:00+06\\")","(57,\\"2024-05-03 12:52:00+06\\")","(58,\\"2024-05-03 12:53:00+06\\")","(59,\\"2024-05-03 12:54:00+06\\")","(60,\\"2024-05-03 12:56:00+06\\")","(61,\\"2024-05-03 12:58:00+06\\")","(62,\\"2024-05-03 13:00:00+06\\")","(63,\\"2024-05-03 13:02:00+06\\")","(70,\\"2024-05-03 13:00:00+06\\")"}	to_buet	Ba-43-4286	t	nobiulnode	nazmul	f	mahmud64	t
4232	2024-05-03 19:40:00+06	7	afternoon	{"(50,\\"2024-05-03 19:40:00+06\\")","(51,\\"2024-05-03 19:48:00+06\\")","(52,\\"2024-05-03 19:50:00+06\\")","(53,\\"2024-05-03 19:52:00+06\\")","(54,\\"2024-05-03 19:54:00+06\\")","(55,\\"2024-05-03 19:56:00+06\\")","(56,\\"2024-05-03 19:58:00+06\\")","(57,\\"2024-05-03 20:00:00+06\\")","(58,\\"2024-05-03 20:02:00+06\\")","(59,\\"2024-05-03 20:04:00+06\\")","(60,\\"2024-05-03 20:06:00+06\\")","(61,\\"2024-05-03 20:08:00+06\\")","(62,\\"2024-05-03 20:10:00+06\\")","(63,\\"2024-05-03 20:12:00+06\\")","(70,\\"2024-05-03 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	polash	nazmul	f	zahir53	t
4233	2024-05-03 12:15:00+06	1	morning	{"(1,\\"2024-05-03 12:15:00+06\\")","(2,\\"2024-05-03 12:18:00+06\\")","(3,\\"2024-05-03 12:20:00+06\\")","(4,\\"2024-05-03 12:23:00+06\\")","(5,\\"2024-05-03 12:26:00+06\\")","(6,\\"2024-05-03 12:29:00+06\\")","(7,\\"2024-05-03 12:49:00+06\\")","(8,\\"2024-05-03 12:51:00+06\\")","(9,\\"2024-05-03 12:53:00+06\\")","(10,\\"2024-05-03 12:55:00+06\\")","(11,\\"2024-05-03 12:58:00+06\\")","(70,\\"2024-05-03 13:05:00+06\\")"}	to_buet	Ba-85-4722	t	monu67	nazmul	f	farid99	t
4234	2024-05-03 19:40:00+06	1	afternoon	{"(1,\\"2024-05-03 19:40:00+06\\")","(2,\\"2024-05-03 19:47:00+06\\")","(3,\\"2024-05-03 19:50:00+06\\")","(4,\\"2024-05-03 19:52:00+06\\")","(5,\\"2024-05-03 19:54:00+06\\")","(6,\\"2024-05-03 20:06:00+06\\")","(7,\\"2024-05-03 20:09:00+06\\")","(8,\\"2024-05-03 20:12:00+06\\")","(9,\\"2024-05-03 20:15:00+06\\")","(10,\\"2024-05-03 20:18:00+06\\")","(11,\\"2024-05-03 20:21:00+06\\")","(70,\\"2024-05-03 20:24:00+06\\")"}	from_buet	Ba-93-6087	t	nazrul6	nazmul	f	kk47	t
4235	2024-05-03 23:30:00+06	7	evening	{"(50,\\"2024-05-03 23:30:00+06\\")","(51,\\"2024-05-03 23:38:00+06\\")","(52,\\"2024-05-03 23:40:00+06\\")","(53,\\"2024-05-03 23:42:00+06\\")","(54,\\"2024-05-03 23:44:00+06\\")","(55,\\"2024-05-03 23:46:00+06\\")","(56,\\"2024-05-03 23:48:00+06\\")","(57,\\"2024-05-03 23:50:00+06\\")","(58,\\"2024-05-03 23:52:00+06\\")","(59,\\"2024-05-03 23:54:00+06\\")","(60,\\"2024-05-03 23:56:00+06\\")","(61,\\"2024-05-03 23:58:00+06\\")","(62,\\"2024-05-03 00:00:00+06\\")","(63,\\"2024-05-03 00:02:00+06\\")","(70,\\"2024-05-03 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	masud84	nazmul	f	reyazul	t
4236	2024-05-03 12:40:00+06	3	morning	{"(17,\\"2024-05-03 12:40:00+06\\")","(18,\\"2024-05-03 12:42:00+06\\")","(19,\\"2024-05-03 12:44:00+06\\")","(20,\\"2024-05-03 12:46:00+06\\")","(21,\\"2024-05-03 12:48:00+06\\")","(22,\\"2024-05-03 12:50:00+06\\")","(23,\\"2024-05-03 12:52:00+06\\")","(24,\\"2024-05-03 12:54:00+06\\")","(25,\\"2024-05-03 12:57:00+06\\")","(26,\\"2024-05-03 13:00:00+06\\")","(70,\\"2024-05-03 13:15:00+06\\")"}	to_buet	Ba-17-3886	t	rashed3	nazmul	f	abdulbari4	t
4237	2024-05-03 19:40:00+06	3	afternoon	{"(17,\\"2024-05-03 19:40:00+06\\")","(18,\\"2024-05-03 19:55:00+06\\")","(19,\\"2024-05-03 19:58:00+06\\")","(20,\\"2024-05-03 20:00:00+06\\")","(21,\\"2024-05-03 20:02:00+06\\")","(22,\\"2024-05-03 20:04:00+06\\")","(23,\\"2024-05-03 20:06:00+06\\")","(24,\\"2024-05-03 20:08:00+06\\")","(25,\\"2024-05-03 20:10:00+06\\")","(26,\\"2024-05-03 20:12:00+06\\")","(70,\\"2024-05-03 20:14:00+06\\")"}	from_buet	Ba-12-8888	t	felicitades35	nazmul	f	rishisunak45	t
4238	2024-05-03 12:40:00+06	4	morning	{"(27,\\"2024-05-03 12:40:00+06\\")","(28,\\"2024-05-03 12:42:00+06\\")","(29,\\"2024-05-03 12:44:00+06\\")","(30,\\"2024-05-03 12:46:00+06\\")","(31,\\"2024-05-03 12:50:00+06\\")","(32,\\"2024-05-03 12:52:00+06\\")","(33,\\"2024-05-03 12:54:00+06\\")","(34,\\"2024-05-03 12:58:00+06\\")","(35,\\"2024-05-03 13:00:00+06\\")","(70,\\"2024-05-03 13:10:00+06\\")"}	to_buet	Ba-69-8288	t	galloway67	nazmul	f	dariengap30	t
4239	2024-05-03 23:30:00+06	8	evening	{"(64,\\"2024-05-03 23:30:00+06\\")","(65,\\"2024-05-03 23:45:00+06\\")","(66,\\"2024-05-03 23:48:00+06\\")","(67,\\"2024-05-03 23:51:00+06\\")","(68,\\"2024-05-03 23:54:00+06\\")","(69,\\"2024-05-03 23:57:00+06\\")","(70,\\"2024-05-03 00:00:00+06\\")"}	from_buet	Ba-19-0569	t	marufmorshed	nazmul	f	jamal7898	t
4240	2024-05-03 12:55:00+06	2	morning	{"(12,\\"2024-05-03 12:55:00+06\\")","(13,\\"2024-05-03 12:57:00+06\\")","(14,\\"2024-05-03 12:59:00+06\\")","(15,\\"2024-05-03 13:01:00+06\\")","(16,\\"2024-05-03 13:03:00+06\\")","(70,\\"2024-05-03 13:15:00+06\\")"}	to_buet	Ba-22-4326	t	aminhaque	nazmul	f	refugee23	t
4241	2024-05-03 19:40:00+06	2	afternoon	{"(12,\\"2024-05-03 19:40:00+06\\")","(13,\\"2024-05-03 19:52:00+06\\")","(14,\\"2024-05-03 19:54:00+06\\")","(15,\\"2024-05-03 19:57:00+06\\")","(16,\\"2024-05-03 20:00:00+06\\")","(70,\\"2024-05-03 20:03:00+06\\")"}	from_buet	Ba-69-8288	t	kamaluddin	nazmul	f	rgbmbrt	t
4242	2024-05-03 23:30:00+06	2	evening	{"(12,\\"2024-05-03 23:30:00+06\\")","(13,\\"2024-05-03 23:42:00+06\\")","(14,\\"2024-05-03 23:45:00+06\\")","(15,\\"2024-05-03 23:48:00+06\\")","(16,\\"2024-05-03 23:51:00+06\\")","(70,\\"2024-05-03 23:54:00+06\\")"}	from_buet	Ba-86-1841	t	altaf	nazmul	f	shamsul54	t
4243	2024-05-03 23:30:00+06	4	evening	{"(27,\\"2024-05-03 23:30:00+06\\")","(28,\\"2024-05-03 23:40:00+06\\")","(29,\\"2024-05-03 23:42:00+06\\")","(30,\\"2024-05-03 23:44:00+06\\")","(31,\\"2024-05-03 23:46:00+06\\")","(32,\\"2024-05-03 23:48:00+06\\")","(33,\\"2024-05-03 23:50:00+06\\")","(34,\\"2024-05-03 23:52:00+06\\")","(35,\\"2024-05-03 23:54:00+06\\")","(70,\\"2024-05-03 23:56:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	f	germs23	t
4244	2024-05-03 12:30:00+06	5	morning	{"(36,\\"2024-05-03 12:30:00+06\\")","(37,\\"2024-05-03 12:33:00+06\\")","(38,\\"2024-05-03 12:40:00+06\\")","(39,\\"2024-05-03 12:45:00+06\\")","(40,\\"2024-05-03 12:50:00+06\\")","(70,\\"2024-05-03 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	nizam88	nazmul	f	rashid56	t
4245	2024-05-03 23:30:00+06	5	evening	{"(36,\\"2024-05-03 23:30:00+06\\")","(37,\\"2024-05-03 23:40:00+06\\")","(38,\\"2024-05-03 23:45:00+06\\")","(39,\\"2024-05-03 23:50:00+06\\")","(40,\\"2024-05-03 23:57:00+06\\")","(70,\\"2024-05-03 00:00:00+06\\")"}	from_buet	Ba-77-7044	t	galloway67	nazmul	f	ghioe22	t
4246	2024-05-03 19:40:00+06	5	afternoon	{"(36,\\"2024-05-03 19:40:00+06\\")","(37,\\"2024-05-03 19:50:00+06\\")","(38,\\"2024-05-03 19:55:00+06\\")","(39,\\"2024-05-03 20:00:00+06\\")","(40,\\"2024-05-03 20:07:00+06\\")","(70,\\"2024-05-03 20:10:00+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	f	mahbub777	t
4247	2024-05-03 23:30:00+06	1	evening	{"(1,\\"2024-05-03 23:30:00+06\\")","(2,\\"2024-05-03 23:37:00+06\\")","(3,\\"2024-05-03 23:40:00+06\\")","(4,\\"2024-05-03 23:42:00+06\\")","(5,\\"2024-05-03 23:44:00+06\\")","(6,\\"2024-05-03 23:56:00+06\\")","(7,\\"2024-05-03 23:59:00+06\\")","(8,\\"2024-05-03 00:02:00+06\\")","(9,\\"2024-05-03 00:05:00+06\\")","(10,\\"2024-05-03 00:08:00+06\\")","(11,\\"2024-05-03 00:11:00+06\\")","(70,\\"2024-05-03 00:14:00+06\\")"}	from_buet	Ba-48-5757	t	abdulkarim6	nazmul	f	siddiq2	t
4248	2024-05-03 12:10:00+06	8	morning	{"(64,\\"2024-05-03 12:10:00+06\\")","(65,\\"2024-05-03 12:13:00+06\\")","(66,\\"2024-05-03 12:18:00+06\\")","(67,\\"2024-05-03 12:20:00+06\\")","(68,\\"2024-05-03 12:22:00+06\\")","(69,\\"2024-05-03 12:25:00+06\\")","(70,\\"2024-05-03 12:40:00+06\\")"}	to_buet	Ba-17-2081	t	shafiqul	nazmul	f	sharif86r	t
4249	2024-05-03 19:40:00+06	8	afternoon	{"(64,\\"2024-05-03 19:40:00+06\\")","(65,\\"2024-05-03 19:55:00+06\\")","(66,\\"2024-05-03 19:58:00+06\\")","(67,\\"2024-05-03 20:01:00+06\\")","(68,\\"2024-05-03 20:04:00+06\\")","(69,\\"2024-05-03 20:07:00+06\\")","(70,\\"2024-05-03 20:10:00+06\\")"}	from_buet	Ba-71-7930	t	jahangir	nazmul	f	khairul	t
4250	2024-05-03 23:30:00+06	3	evening	{"(17,\\"2024-05-03 23:30:00+06\\")","(18,\\"2024-05-03 23:45:00+06\\")","(19,\\"2024-05-03 23:48:00+06\\")","(20,\\"2024-05-03 23:50:00+06\\")","(21,\\"2024-05-03 23:52:00+06\\")","(22,\\"2024-05-03 23:54:00+06\\")","(23,\\"2024-05-03 23:56:00+06\\")","(24,\\"2024-05-03 23:58:00+06\\")","(25,\\"2024-05-03 00:00:00+06\\")","(26,\\"2024-05-03 00:02:00+06\\")","(70,\\"2024-05-03 00:04:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81	t
4251	2024-05-03 19:40:00+06	4	afternoon	{"(27,\\"2024-05-03 19:40:00+06\\")","(28,\\"2024-05-03 19:50:00+06\\")","(29,\\"2024-05-03 19:52:00+06\\")","(30,\\"2024-05-03 19:54:00+06\\")","(31,\\"2024-05-03 19:56:00+06\\")","(32,\\"2024-05-03 19:58:00+06\\")","(33,\\"2024-05-03 20:00:00+06\\")","(34,\\"2024-05-03 20:02:00+06\\")","(35,\\"2024-05-03 20:04:00+06\\")","(70,\\"2024-05-03 20:06:00+06\\")"}	from_buet	BA-01-2345	t	ibrahim	nazmul	f	greece01	t
4252	2024-05-04 23:30:00+06	6	evening	{"(41,\\"2024-05-04 23:30:00+06\\")","(42,\\"2024-05-04 23:46:00+06\\")","(43,\\"2024-05-04 23:48:00+06\\")","(44,\\"2024-05-04 23:50:00+06\\")","(45,\\"2024-05-04 23:52:00+06\\")","(46,\\"2024-05-04 23:54:00+06\\")","(47,\\"2024-05-04 23:56:00+06\\")","(48,\\"2024-05-04 23:58:00+06\\")","(49,\\"2024-05-04 00:00:00+06\\")","(70,\\"2024-05-04 00:02:00+06\\")"}	from_buet	Ba-83-8014	t	altaf78	nazmul	f	mahabhu	t
4253	2024-05-04 12:40:00+06	6	morning	{"(41,\\"2024-05-04 12:40:00+06\\")","(42,\\"2024-05-04 12:42:00+06\\")","(43,\\"2024-05-04 12:45:00+06\\")","(44,\\"2024-05-04 12:47:00+06\\")","(45,\\"2024-05-04 12:49:00+06\\")","(46,\\"2024-05-04 12:51:00+06\\")","(47,\\"2024-05-04 12:52:00+06\\")","(48,\\"2024-05-04 12:53:00+06\\")","(49,\\"2024-05-04 12:54:00+06\\")","(70,\\"2024-05-04 13:10:00+06\\")"}	to_buet	Ba-97-6734	t	shahid88	nazmul	f	azim990	t
4254	2024-05-04 19:40:00+06	6	afternoon	{"(41,\\"2024-05-04 19:40:00+06\\")","(42,\\"2024-05-04 19:56:00+06\\")","(43,\\"2024-05-04 19:58:00+06\\")","(44,\\"2024-05-04 20:00:00+06\\")","(45,\\"2024-05-04 20:02:00+06\\")","(46,\\"2024-05-04 20:04:00+06\\")","(47,\\"2024-05-04 20:06:00+06\\")","(48,\\"2024-05-04 20:08:00+06\\")","(49,\\"2024-05-04 20:10:00+06\\")","(70,\\"2024-05-04 20:12:00+06\\")"}	from_buet	Ba-36-1921	t	imranhashmi	nazmul	f	siam34	t
4255	2024-05-04 12:40:00+06	7	morning	{"(50,\\"2024-05-04 12:40:00+06\\")","(51,\\"2024-05-04 12:42:00+06\\")","(52,\\"2024-05-04 12:43:00+06\\")","(53,\\"2024-05-04 12:46:00+06\\")","(54,\\"2024-05-04 12:47:00+06\\")","(55,\\"2024-05-04 12:48:00+06\\")","(56,\\"2024-05-04 12:50:00+06\\")","(57,\\"2024-05-04 12:52:00+06\\")","(58,\\"2024-05-04 12:53:00+06\\")","(59,\\"2024-05-04 12:54:00+06\\")","(60,\\"2024-05-04 12:56:00+06\\")","(61,\\"2024-05-04 12:58:00+06\\")","(62,\\"2024-05-04 13:00:00+06\\")","(63,\\"2024-05-04 13:02:00+06\\")","(70,\\"2024-05-04 13:00:00+06\\")"}	to_buet	Ba-43-4286	t	nobiulnode	nazmul	f	mahmud64	t
4256	2024-05-04 19:40:00+06	7	afternoon	{"(50,\\"2024-05-04 19:40:00+06\\")","(51,\\"2024-05-04 19:48:00+06\\")","(52,\\"2024-05-04 19:50:00+06\\")","(53,\\"2024-05-04 19:52:00+06\\")","(54,\\"2024-05-04 19:54:00+06\\")","(55,\\"2024-05-04 19:56:00+06\\")","(56,\\"2024-05-04 19:58:00+06\\")","(57,\\"2024-05-04 20:00:00+06\\")","(58,\\"2024-05-04 20:02:00+06\\")","(59,\\"2024-05-04 20:04:00+06\\")","(60,\\"2024-05-04 20:06:00+06\\")","(61,\\"2024-05-04 20:08:00+06\\")","(62,\\"2024-05-04 20:10:00+06\\")","(63,\\"2024-05-04 20:12:00+06\\")","(70,\\"2024-05-04 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	polash	nazmul	f	zahir53	t
4257	2024-05-04 12:15:00+06	1	morning	{"(1,\\"2024-05-04 12:15:00+06\\")","(2,\\"2024-05-04 12:18:00+06\\")","(3,\\"2024-05-04 12:20:00+06\\")","(4,\\"2024-05-04 12:23:00+06\\")","(5,\\"2024-05-04 12:26:00+06\\")","(6,\\"2024-05-04 12:29:00+06\\")","(7,\\"2024-05-04 12:49:00+06\\")","(8,\\"2024-05-04 12:51:00+06\\")","(9,\\"2024-05-04 12:53:00+06\\")","(10,\\"2024-05-04 12:55:00+06\\")","(11,\\"2024-05-04 12:58:00+06\\")","(70,\\"2024-05-04 13:05:00+06\\")"}	to_buet	Ba-85-4722	t	monu67	nazmul	f	farid99	t
4258	2024-05-04 19:40:00+06	1	afternoon	{"(1,\\"2024-05-04 19:40:00+06\\")","(2,\\"2024-05-04 19:47:00+06\\")","(3,\\"2024-05-04 19:50:00+06\\")","(4,\\"2024-05-04 19:52:00+06\\")","(5,\\"2024-05-04 19:54:00+06\\")","(6,\\"2024-05-04 20:06:00+06\\")","(7,\\"2024-05-04 20:09:00+06\\")","(8,\\"2024-05-04 20:12:00+06\\")","(9,\\"2024-05-04 20:15:00+06\\")","(10,\\"2024-05-04 20:18:00+06\\")","(11,\\"2024-05-04 20:21:00+06\\")","(70,\\"2024-05-04 20:24:00+06\\")"}	from_buet	Ba-93-6087	t	nazrul6	nazmul	f	kk47	t
4259	2024-05-04 23:30:00+06	7	evening	{"(50,\\"2024-05-04 23:30:00+06\\")","(51,\\"2024-05-04 23:38:00+06\\")","(52,\\"2024-05-04 23:40:00+06\\")","(53,\\"2024-05-04 23:42:00+06\\")","(54,\\"2024-05-04 23:44:00+06\\")","(55,\\"2024-05-04 23:46:00+06\\")","(56,\\"2024-05-04 23:48:00+06\\")","(57,\\"2024-05-04 23:50:00+06\\")","(58,\\"2024-05-04 23:52:00+06\\")","(59,\\"2024-05-04 23:54:00+06\\")","(60,\\"2024-05-04 23:56:00+06\\")","(61,\\"2024-05-04 23:58:00+06\\")","(62,\\"2024-05-04 00:00:00+06\\")","(63,\\"2024-05-04 00:02:00+06\\")","(70,\\"2024-05-04 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	masud84	nazmul	f	reyazul	t
4260	2024-05-04 12:40:00+06	3	morning	{"(17,\\"2024-05-04 12:40:00+06\\")","(18,\\"2024-05-04 12:42:00+06\\")","(19,\\"2024-05-04 12:44:00+06\\")","(20,\\"2024-05-04 12:46:00+06\\")","(21,\\"2024-05-04 12:48:00+06\\")","(22,\\"2024-05-04 12:50:00+06\\")","(23,\\"2024-05-04 12:52:00+06\\")","(24,\\"2024-05-04 12:54:00+06\\")","(25,\\"2024-05-04 12:57:00+06\\")","(26,\\"2024-05-04 13:00:00+06\\")","(70,\\"2024-05-04 13:15:00+06\\")"}	to_buet	Ba-17-3886	t	rashed3	nazmul	f	abdulbari4	t
4261	2024-05-04 19:40:00+06	3	afternoon	{"(17,\\"2024-05-04 19:40:00+06\\")","(18,\\"2024-05-04 19:55:00+06\\")","(19,\\"2024-05-04 19:58:00+06\\")","(20,\\"2024-05-04 20:00:00+06\\")","(21,\\"2024-05-04 20:02:00+06\\")","(22,\\"2024-05-04 20:04:00+06\\")","(23,\\"2024-05-04 20:06:00+06\\")","(24,\\"2024-05-04 20:08:00+06\\")","(25,\\"2024-05-04 20:10:00+06\\")","(26,\\"2024-05-04 20:12:00+06\\")","(70,\\"2024-05-04 20:14:00+06\\")"}	from_buet	Ba-12-8888	t	felicitades35	nazmul	f	rishisunak45	t
4262	2024-05-04 12:40:00+06	4	morning	{"(27,\\"2024-05-04 12:40:00+06\\")","(28,\\"2024-05-04 12:42:00+06\\")","(29,\\"2024-05-04 12:44:00+06\\")","(30,\\"2024-05-04 12:46:00+06\\")","(31,\\"2024-05-04 12:50:00+06\\")","(32,\\"2024-05-04 12:52:00+06\\")","(33,\\"2024-05-04 12:54:00+06\\")","(34,\\"2024-05-04 12:58:00+06\\")","(35,\\"2024-05-04 13:00:00+06\\")","(70,\\"2024-05-04 13:10:00+06\\")"}	to_buet	Ba-69-8288	t	galloway67	nazmul	f	dariengap30	t
4263	2024-05-04 23:30:00+06	8	evening	{"(64,\\"2024-05-04 23:30:00+06\\")","(65,\\"2024-05-04 23:45:00+06\\")","(66,\\"2024-05-04 23:48:00+06\\")","(67,\\"2024-05-04 23:51:00+06\\")","(68,\\"2024-05-04 23:54:00+06\\")","(69,\\"2024-05-04 23:57:00+06\\")","(70,\\"2024-05-04 00:00:00+06\\")"}	from_buet	Ba-19-0569	t	marufmorshed	nazmul	f	jamal7898	t
4264	2024-05-04 12:55:00+06	2	morning	{"(12,\\"2024-05-04 12:55:00+06\\")","(13,\\"2024-05-04 12:57:00+06\\")","(14,\\"2024-05-04 12:59:00+06\\")","(15,\\"2024-05-04 13:01:00+06\\")","(16,\\"2024-05-04 13:03:00+06\\")","(70,\\"2024-05-04 13:15:00+06\\")"}	to_buet	Ba-22-4326	t	aminhaque	nazmul	f	refugee23	t
4265	2024-05-04 19:40:00+06	2	afternoon	{"(12,\\"2024-05-04 19:40:00+06\\")","(13,\\"2024-05-04 19:52:00+06\\")","(14,\\"2024-05-04 19:54:00+06\\")","(15,\\"2024-05-04 19:57:00+06\\")","(16,\\"2024-05-04 20:00:00+06\\")","(70,\\"2024-05-04 20:03:00+06\\")"}	from_buet	Ba-69-8288	t	kamaluddin	nazmul	f	rgbmbrt	t
4266	2024-05-04 23:30:00+06	2	evening	{"(12,\\"2024-05-04 23:30:00+06\\")","(13,\\"2024-05-04 23:42:00+06\\")","(14,\\"2024-05-04 23:45:00+06\\")","(15,\\"2024-05-04 23:48:00+06\\")","(16,\\"2024-05-04 23:51:00+06\\")","(70,\\"2024-05-04 23:54:00+06\\")"}	from_buet	Ba-86-1841	t	altaf	nazmul	f	shamsul54	t
4267	2024-05-04 23:30:00+06	4	evening	{"(27,\\"2024-05-04 23:30:00+06\\")","(28,\\"2024-05-04 23:40:00+06\\")","(29,\\"2024-05-04 23:42:00+06\\")","(30,\\"2024-05-04 23:44:00+06\\")","(31,\\"2024-05-04 23:46:00+06\\")","(32,\\"2024-05-04 23:48:00+06\\")","(33,\\"2024-05-04 23:50:00+06\\")","(34,\\"2024-05-04 23:52:00+06\\")","(35,\\"2024-05-04 23:54:00+06\\")","(70,\\"2024-05-04 23:56:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	f	germs23	t
4268	2024-05-04 12:30:00+06	5	morning	{"(36,\\"2024-05-04 12:30:00+06\\")","(37,\\"2024-05-04 12:33:00+06\\")","(38,\\"2024-05-04 12:40:00+06\\")","(39,\\"2024-05-04 12:45:00+06\\")","(40,\\"2024-05-04 12:50:00+06\\")","(70,\\"2024-05-04 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	nizam88	nazmul	f	rashid56	t
4269	2024-05-04 23:30:00+06	5	evening	{"(36,\\"2024-05-04 23:30:00+06\\")","(37,\\"2024-05-04 23:40:00+06\\")","(38,\\"2024-05-04 23:45:00+06\\")","(39,\\"2024-05-04 23:50:00+06\\")","(40,\\"2024-05-04 23:57:00+06\\")","(70,\\"2024-05-04 00:00:00+06\\")"}	from_buet	Ba-77-7044	t	galloway67	nazmul	f	ghioe22	t
4270	2024-05-04 19:40:00+06	5	afternoon	{"(36,\\"2024-05-04 19:40:00+06\\")","(37,\\"2024-05-04 19:50:00+06\\")","(38,\\"2024-05-04 19:55:00+06\\")","(39,\\"2024-05-04 20:00:00+06\\")","(40,\\"2024-05-04 20:07:00+06\\")","(70,\\"2024-05-04 20:10:00+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	f	mahbub777	t
4271	2024-05-04 23:30:00+06	1	evening	{"(1,\\"2024-05-04 23:30:00+06\\")","(2,\\"2024-05-04 23:37:00+06\\")","(3,\\"2024-05-04 23:40:00+06\\")","(4,\\"2024-05-04 23:42:00+06\\")","(5,\\"2024-05-04 23:44:00+06\\")","(6,\\"2024-05-04 23:56:00+06\\")","(7,\\"2024-05-04 23:59:00+06\\")","(8,\\"2024-05-04 00:02:00+06\\")","(9,\\"2024-05-04 00:05:00+06\\")","(10,\\"2024-05-04 00:08:00+06\\")","(11,\\"2024-05-04 00:11:00+06\\")","(70,\\"2024-05-04 00:14:00+06\\")"}	from_buet	Ba-48-5757	t	abdulkarim6	nazmul	f	siddiq2	t
4272	2024-05-04 12:10:00+06	8	morning	{"(64,\\"2024-05-04 12:10:00+06\\")","(65,\\"2024-05-04 12:13:00+06\\")","(66,\\"2024-05-04 12:18:00+06\\")","(67,\\"2024-05-04 12:20:00+06\\")","(68,\\"2024-05-04 12:22:00+06\\")","(69,\\"2024-05-04 12:25:00+06\\")","(70,\\"2024-05-04 12:40:00+06\\")"}	to_buet	Ba-17-2081	t	shafiqul	nazmul	f	sharif86r	t
4273	2024-05-04 19:40:00+06	8	afternoon	{"(64,\\"2024-05-04 19:40:00+06\\")","(65,\\"2024-05-04 19:55:00+06\\")","(66,\\"2024-05-04 19:58:00+06\\")","(67,\\"2024-05-04 20:01:00+06\\")","(68,\\"2024-05-04 20:04:00+06\\")","(69,\\"2024-05-04 20:07:00+06\\")","(70,\\"2024-05-04 20:10:00+06\\")"}	from_buet	Ba-71-7930	t	jahangir	nazmul	f	khairul	t
4274	2024-05-04 23:30:00+06	3	evening	{"(17,\\"2024-05-04 23:30:00+06\\")","(18,\\"2024-05-04 23:45:00+06\\")","(19,\\"2024-05-04 23:48:00+06\\")","(20,\\"2024-05-04 23:50:00+06\\")","(21,\\"2024-05-04 23:52:00+06\\")","(22,\\"2024-05-04 23:54:00+06\\")","(23,\\"2024-05-04 23:56:00+06\\")","(24,\\"2024-05-04 23:58:00+06\\")","(25,\\"2024-05-04 00:00:00+06\\")","(26,\\"2024-05-04 00:02:00+06\\")","(70,\\"2024-05-04 00:04:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81	t
4275	2024-05-04 19:40:00+06	4	afternoon	{"(27,\\"2024-05-04 19:40:00+06\\")","(28,\\"2024-05-04 19:50:00+06\\")","(29,\\"2024-05-04 19:52:00+06\\")","(30,\\"2024-05-04 19:54:00+06\\")","(31,\\"2024-05-04 19:56:00+06\\")","(32,\\"2024-05-04 19:58:00+06\\")","(33,\\"2024-05-04 20:00:00+06\\")","(34,\\"2024-05-04 20:02:00+06\\")","(35,\\"2024-05-04 20:04:00+06\\")","(70,\\"2024-05-04 20:06:00+06\\")"}	from_buet	BA-01-2345	t	ibrahim	nazmul	f	greece01	t
4084	2024-04-27 23:30:00+06	6	evening	{"(41,\\"2024-04-27 23:30:00+06\\")","(42,\\"2024-04-27 23:46:00+06\\")","(43,\\"2024-04-27 23:48:00+06\\")","(44,\\"2024-04-27 23:50:00+06\\")","(45,\\"2024-04-27 23:52:00+06\\")","(46,\\"2024-04-27 23:54:00+06\\")","(47,\\"2024-04-27 23:56:00+06\\")","(48,\\"2024-04-27 23:58:00+06\\")","(49,\\"2024-04-27 00:00:00+06\\")","(70,\\"2024-04-27 00:02:00+06\\")"}	from_buet	Ba-83-8014	t	altaf78	nazmul	f	mahabhu	t
4085	2024-04-27 12:40:00+06	6	morning	{"(41,\\"2024-04-27 12:40:00+06\\")","(42,\\"2024-04-27 12:42:00+06\\")","(43,\\"2024-04-27 12:45:00+06\\")","(44,\\"2024-04-27 12:47:00+06\\")","(45,\\"2024-04-27 12:49:00+06\\")","(46,\\"2024-04-27 12:51:00+06\\")","(47,\\"2024-04-27 12:52:00+06\\")","(48,\\"2024-04-27 12:53:00+06\\")","(49,\\"2024-04-27 12:54:00+06\\")","(70,\\"2024-04-27 13:10:00+06\\")"}	to_buet	Ba-97-6734	t	shahid88	nazmul	f	azim990	t
4086	2024-04-27 19:40:00+06	6	afternoon	{"(41,\\"2024-04-27 19:40:00+06\\")","(42,\\"2024-04-27 19:56:00+06\\")","(43,\\"2024-04-27 19:58:00+06\\")","(44,\\"2024-04-27 20:00:00+06\\")","(45,\\"2024-04-27 20:02:00+06\\")","(46,\\"2024-04-27 20:04:00+06\\")","(47,\\"2024-04-27 20:06:00+06\\")","(48,\\"2024-04-27 20:08:00+06\\")","(49,\\"2024-04-27 20:10:00+06\\")","(70,\\"2024-04-27 20:12:00+06\\")"}	from_buet	Ba-36-1921	t	imranhashmi	nazmul	f	siam34	t
4087	2024-04-27 12:40:00+06	7	morning	{"(50,\\"2024-04-27 12:40:00+06\\")","(51,\\"2024-04-27 12:42:00+06\\")","(52,\\"2024-04-27 12:43:00+06\\")","(53,\\"2024-04-27 12:46:00+06\\")","(54,\\"2024-04-27 12:47:00+06\\")","(55,\\"2024-04-27 12:48:00+06\\")","(56,\\"2024-04-27 12:50:00+06\\")","(57,\\"2024-04-27 12:52:00+06\\")","(58,\\"2024-04-27 12:53:00+06\\")","(59,\\"2024-04-27 12:54:00+06\\")","(60,\\"2024-04-27 12:56:00+06\\")","(61,\\"2024-04-27 12:58:00+06\\")","(62,\\"2024-04-27 13:00:00+06\\")","(63,\\"2024-04-27 13:02:00+06\\")","(70,\\"2024-04-27 13:00:00+06\\")"}	to_buet	Ba-43-4286	t	nobiulnode	nazmul	f	mahmud64	t
4088	2024-04-27 19:40:00+06	7	afternoon	{"(50,\\"2024-04-27 19:40:00+06\\")","(51,\\"2024-04-27 19:48:00+06\\")","(52,\\"2024-04-27 19:50:00+06\\")","(53,\\"2024-04-27 19:52:00+06\\")","(54,\\"2024-04-27 19:54:00+06\\")","(55,\\"2024-04-27 19:56:00+06\\")","(56,\\"2024-04-27 19:58:00+06\\")","(57,\\"2024-04-27 20:00:00+06\\")","(58,\\"2024-04-27 20:02:00+06\\")","(59,\\"2024-04-27 20:04:00+06\\")","(60,\\"2024-04-27 20:06:00+06\\")","(61,\\"2024-04-27 20:08:00+06\\")","(62,\\"2024-04-27 20:10:00+06\\")","(63,\\"2024-04-27 20:12:00+06\\")","(70,\\"2024-04-27 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	polash	nazmul	f	zahir53	t
4089	2024-04-27 12:15:00+06	1	morning	{"(1,\\"2024-04-27 12:15:00+06\\")","(2,\\"2024-04-27 12:18:00+06\\")","(3,\\"2024-04-27 12:20:00+06\\")","(4,\\"2024-04-27 12:23:00+06\\")","(5,\\"2024-04-27 12:26:00+06\\")","(6,\\"2024-04-27 12:29:00+06\\")","(7,\\"2024-04-27 12:49:00+06\\")","(8,\\"2024-04-27 12:51:00+06\\")","(9,\\"2024-04-27 12:53:00+06\\")","(10,\\"2024-04-27 12:55:00+06\\")","(11,\\"2024-04-27 12:58:00+06\\")","(70,\\"2024-04-27 13:05:00+06\\")"}	to_buet	Ba-85-4722	t	monu67	nazmul	f	farid99	t
4090	2024-04-27 19:40:00+06	1	afternoon	{"(1,\\"2024-04-27 19:40:00+06\\")","(2,\\"2024-04-27 19:47:00+06\\")","(3,\\"2024-04-27 19:50:00+06\\")","(4,\\"2024-04-27 19:52:00+06\\")","(5,\\"2024-04-27 19:54:00+06\\")","(6,\\"2024-04-27 20:06:00+06\\")","(7,\\"2024-04-27 20:09:00+06\\")","(8,\\"2024-04-27 20:12:00+06\\")","(9,\\"2024-04-27 20:15:00+06\\")","(10,\\"2024-04-27 20:18:00+06\\")","(11,\\"2024-04-27 20:21:00+06\\")","(70,\\"2024-04-27 20:24:00+06\\")"}	from_buet	Ba-93-6087	t	nazrul6	nazmul	f	kk47	t
4091	2024-04-27 23:30:00+06	7	evening	{"(50,\\"2024-04-27 23:30:00+06\\")","(51,\\"2024-04-27 23:38:00+06\\")","(52,\\"2024-04-27 23:40:00+06\\")","(53,\\"2024-04-27 23:42:00+06\\")","(54,\\"2024-04-27 23:44:00+06\\")","(55,\\"2024-04-27 23:46:00+06\\")","(56,\\"2024-04-27 23:48:00+06\\")","(57,\\"2024-04-27 23:50:00+06\\")","(58,\\"2024-04-27 23:52:00+06\\")","(59,\\"2024-04-27 23:54:00+06\\")","(60,\\"2024-04-27 23:56:00+06\\")","(61,\\"2024-04-27 23:58:00+06\\")","(62,\\"2024-04-27 00:00:00+06\\")","(63,\\"2024-04-27 00:02:00+06\\")","(70,\\"2024-04-27 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	masud84	nazmul	f	reyazul	t
4092	2024-04-27 12:40:00+06	3	morning	{"(17,\\"2024-04-27 12:40:00+06\\")","(18,\\"2024-04-27 12:42:00+06\\")","(19,\\"2024-04-27 12:44:00+06\\")","(20,\\"2024-04-27 12:46:00+06\\")","(21,\\"2024-04-27 12:48:00+06\\")","(22,\\"2024-04-27 12:50:00+06\\")","(23,\\"2024-04-27 12:52:00+06\\")","(24,\\"2024-04-27 12:54:00+06\\")","(25,\\"2024-04-27 12:57:00+06\\")","(26,\\"2024-04-27 13:00:00+06\\")","(70,\\"2024-04-27 13:15:00+06\\")"}	to_buet	Ba-17-3886	t	rashed3	nazmul	f	abdulbari4	t
4093	2024-04-27 19:40:00+06	3	afternoon	{"(17,\\"2024-04-27 19:40:00+06\\")","(18,\\"2024-04-27 19:55:00+06\\")","(19,\\"2024-04-27 19:58:00+06\\")","(20,\\"2024-04-27 20:00:00+06\\")","(21,\\"2024-04-27 20:02:00+06\\")","(22,\\"2024-04-27 20:04:00+06\\")","(23,\\"2024-04-27 20:06:00+06\\")","(24,\\"2024-04-27 20:08:00+06\\")","(25,\\"2024-04-27 20:10:00+06\\")","(26,\\"2024-04-27 20:12:00+06\\")","(70,\\"2024-04-27 20:14:00+06\\")"}	from_buet	Ba-12-8888	t	felicitades35	nazmul	f	rishisunak45	t
4094	2024-04-27 12:40:00+06	4	morning	{"(27,\\"2024-04-27 12:40:00+06\\")","(28,\\"2024-04-27 12:42:00+06\\")","(29,\\"2024-04-27 12:44:00+06\\")","(30,\\"2024-04-27 12:46:00+06\\")","(31,\\"2024-04-27 12:50:00+06\\")","(32,\\"2024-04-27 12:52:00+06\\")","(33,\\"2024-04-27 12:54:00+06\\")","(34,\\"2024-04-27 12:58:00+06\\")","(35,\\"2024-04-27 13:00:00+06\\")","(70,\\"2024-04-27 13:10:00+06\\")"}	to_buet	Ba-69-8288	t	galloway67	nazmul	f	dariengap30	t
4095	2024-04-27 23:30:00+06	8	evening	{"(64,\\"2024-04-27 23:30:00+06\\")","(65,\\"2024-04-27 23:45:00+06\\")","(66,\\"2024-04-27 23:48:00+06\\")","(67,\\"2024-04-27 23:51:00+06\\")","(68,\\"2024-04-27 23:54:00+06\\")","(69,\\"2024-04-27 23:57:00+06\\")","(70,\\"2024-04-27 00:00:00+06\\")"}	from_buet	Ba-19-0569	t	marufmorshed	nazmul	f	jamal7898	t
4096	2024-04-27 12:55:00+06	2	morning	{"(12,\\"2024-04-27 12:55:00+06\\")","(13,\\"2024-04-27 12:57:00+06\\")","(14,\\"2024-04-27 12:59:00+06\\")","(15,\\"2024-04-27 13:01:00+06\\")","(16,\\"2024-04-27 13:03:00+06\\")","(70,\\"2024-04-27 13:15:00+06\\")"}	to_buet	Ba-22-4326	t	aminhaque	nazmul	f	refugee23	t
4097	2024-04-27 19:40:00+06	2	afternoon	{"(12,\\"2024-04-27 19:40:00+06\\")","(13,\\"2024-04-27 19:52:00+06\\")","(14,\\"2024-04-27 19:54:00+06\\")","(15,\\"2024-04-27 19:57:00+06\\")","(16,\\"2024-04-27 20:00:00+06\\")","(70,\\"2024-04-27 20:03:00+06\\")"}	from_buet	Ba-69-8288	t	kamaluddin	nazmul	f	rgbmbrt	t
4098	2024-04-27 23:30:00+06	2	evening	{"(12,\\"2024-04-27 23:30:00+06\\")","(13,\\"2024-04-27 23:42:00+06\\")","(14,\\"2024-04-27 23:45:00+06\\")","(15,\\"2024-04-27 23:48:00+06\\")","(16,\\"2024-04-27 23:51:00+06\\")","(70,\\"2024-04-27 23:54:00+06\\")"}	from_buet	Ba-86-1841	t	altaf	nazmul	f	shamsul54	t
4099	2024-04-27 23:30:00+06	4	evening	{"(27,\\"2024-04-27 23:30:00+06\\")","(28,\\"2024-04-27 23:40:00+06\\")","(29,\\"2024-04-27 23:42:00+06\\")","(30,\\"2024-04-27 23:44:00+06\\")","(31,\\"2024-04-27 23:46:00+06\\")","(32,\\"2024-04-27 23:48:00+06\\")","(33,\\"2024-04-27 23:50:00+06\\")","(34,\\"2024-04-27 23:52:00+06\\")","(35,\\"2024-04-27 23:54:00+06\\")","(70,\\"2024-04-27 23:56:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	f	germs23	t
4101	2024-04-27 23:30:00+06	5	evening	{"(36,\\"2024-04-27 23:30:00+06\\")","(37,\\"2024-04-27 23:40:00+06\\")","(38,\\"2024-04-27 23:45:00+06\\")","(39,\\"2024-04-27 23:50:00+06\\")","(40,\\"2024-04-27 23:57:00+06\\")","(70,\\"2024-04-27 00:00:00+06\\")"}	from_buet	Ba-77-7044	t	galloway67	nazmul	f	ghioe22	t
4103	2024-04-27 23:30:00+06	1	evening	{"(1,\\"2024-04-27 23:30:00+06\\")","(2,\\"2024-04-27 23:37:00+06\\")","(3,\\"2024-04-27 23:40:00+06\\")","(4,\\"2024-04-27 23:42:00+06\\")","(5,\\"2024-04-27 23:44:00+06\\")","(6,\\"2024-04-27 23:56:00+06\\")","(7,\\"2024-04-27 23:59:00+06\\")","(8,\\"2024-04-27 00:02:00+06\\")","(9,\\"2024-04-27 00:05:00+06\\")","(10,\\"2024-04-27 00:08:00+06\\")","(11,\\"2024-04-27 00:11:00+06\\")","(70,\\"2024-04-27 00:14:00+06\\")"}	from_buet	Ba-48-5757	t	abdulkarim6	nazmul	f	siddiq2	t
4104	2024-04-27 12:10:00+06	8	morning	{"(64,\\"2024-04-27 12:10:00+06\\")","(65,\\"2024-04-27 12:13:00+06\\")","(66,\\"2024-04-27 12:18:00+06\\")","(67,\\"2024-04-27 12:20:00+06\\")","(68,\\"2024-04-27 12:22:00+06\\")","(69,\\"2024-04-27 12:25:00+06\\")","(70,\\"2024-04-27 12:40:00+06\\")"}	to_buet	Ba-17-2081	t	shafiqul	nazmul	f	sharif86r	t
4105	2024-04-27 19:40:00+06	8	afternoon	{"(64,\\"2024-04-27 19:40:00+06\\")","(65,\\"2024-04-27 19:55:00+06\\")","(66,\\"2024-04-27 19:58:00+06\\")","(67,\\"2024-04-27 20:01:00+06\\")","(68,\\"2024-04-27 20:04:00+06\\")","(69,\\"2024-04-27 20:07:00+06\\")","(70,\\"2024-04-27 20:10:00+06\\")"}	from_buet	Ba-71-7930	t	jahangir	nazmul	f	khairul	t
4106	2024-04-27 23:30:00+06	3	evening	{"(17,\\"2024-04-27 23:30:00+06\\")","(18,\\"2024-04-27 23:45:00+06\\")","(19,\\"2024-04-27 23:48:00+06\\")","(20,\\"2024-04-27 23:50:00+06\\")","(21,\\"2024-04-27 23:52:00+06\\")","(22,\\"2024-04-27 23:54:00+06\\")","(23,\\"2024-04-27 23:56:00+06\\")","(24,\\"2024-04-27 23:58:00+06\\")","(25,\\"2024-04-27 00:00:00+06\\")","(26,\\"2024-04-27 00:02:00+06\\")","(70,\\"2024-04-27 00:04:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81	t
4107	2024-04-27 19:40:00+06	4	afternoon	{"(27,\\"2024-04-27 19:40:00+06\\")","(28,\\"2024-04-27 19:50:00+06\\")","(29,\\"2024-04-27 19:52:00+06\\")","(30,\\"2024-04-27 19:54:00+06\\")","(31,\\"2024-04-27 19:56:00+06\\")","(32,\\"2024-04-27 19:58:00+06\\")","(33,\\"2024-04-27 20:00:00+06\\")","(34,\\"2024-04-27 20:02:00+06\\")","(35,\\"2024-04-27 20:04:00+06\\")","(70,\\"2024-04-27 20:06:00+06\\")"}	from_buet	BA-01-2345	t	ibrahim	nazmul	f	greece01	t
4108	2024-04-28 23:30:00+06	6	evening	{"(41,\\"2024-04-28 23:30:00+06\\")","(42,\\"2024-04-28 23:46:00+06\\")","(43,\\"2024-04-28 23:48:00+06\\")","(44,\\"2024-04-28 23:50:00+06\\")","(45,\\"2024-04-28 23:52:00+06\\")","(46,\\"2024-04-28 23:54:00+06\\")","(47,\\"2024-04-28 23:56:00+06\\")","(48,\\"2024-04-28 23:58:00+06\\")","(49,\\"2024-04-28 00:00:00+06\\")","(70,\\"2024-04-28 00:02:00+06\\")"}	from_buet	Ba-83-8014	t	altaf78	nazmul	f	mahabhu	t
4109	2024-04-28 12:40:00+06	6	morning	{"(41,\\"2024-04-28 12:40:00+06\\")","(42,\\"2024-04-28 12:42:00+06\\")","(43,\\"2024-04-28 12:45:00+06\\")","(44,\\"2024-04-28 12:47:00+06\\")","(45,\\"2024-04-28 12:49:00+06\\")","(46,\\"2024-04-28 12:51:00+06\\")","(47,\\"2024-04-28 12:52:00+06\\")","(48,\\"2024-04-28 12:53:00+06\\")","(49,\\"2024-04-28 12:54:00+06\\")","(70,\\"2024-04-28 13:10:00+06\\")"}	to_buet	Ba-97-6734	t	shahid88	nazmul	f	azim990	t
4110	2024-04-28 19:40:00+06	6	afternoon	{"(41,\\"2024-04-28 19:40:00+06\\")","(42,\\"2024-04-28 19:56:00+06\\")","(43,\\"2024-04-28 19:58:00+06\\")","(44,\\"2024-04-28 20:00:00+06\\")","(45,\\"2024-04-28 20:02:00+06\\")","(46,\\"2024-04-28 20:04:00+06\\")","(47,\\"2024-04-28 20:06:00+06\\")","(48,\\"2024-04-28 20:08:00+06\\")","(49,\\"2024-04-28 20:10:00+06\\")","(70,\\"2024-04-28 20:12:00+06\\")"}	from_buet	Ba-36-1921	t	imranhashmi	nazmul	f	siam34	t
4111	2024-04-28 12:40:00+06	7	morning	{"(50,\\"2024-04-28 12:40:00+06\\")","(51,\\"2024-04-28 12:42:00+06\\")","(52,\\"2024-04-28 12:43:00+06\\")","(53,\\"2024-04-28 12:46:00+06\\")","(54,\\"2024-04-28 12:47:00+06\\")","(55,\\"2024-04-28 12:48:00+06\\")","(56,\\"2024-04-28 12:50:00+06\\")","(57,\\"2024-04-28 12:52:00+06\\")","(58,\\"2024-04-28 12:53:00+06\\")","(59,\\"2024-04-28 12:54:00+06\\")","(60,\\"2024-04-28 12:56:00+06\\")","(61,\\"2024-04-28 12:58:00+06\\")","(62,\\"2024-04-28 13:00:00+06\\")","(63,\\"2024-04-28 13:02:00+06\\")","(70,\\"2024-04-28 13:00:00+06\\")"}	to_buet	Ba-43-4286	t	nobiulnode	nazmul	f	mahmud64	t
4112	2024-04-28 19:40:00+06	7	afternoon	{"(50,\\"2024-04-28 19:40:00+06\\")","(51,\\"2024-04-28 19:48:00+06\\")","(52,\\"2024-04-28 19:50:00+06\\")","(53,\\"2024-04-28 19:52:00+06\\")","(54,\\"2024-04-28 19:54:00+06\\")","(55,\\"2024-04-28 19:56:00+06\\")","(56,\\"2024-04-28 19:58:00+06\\")","(57,\\"2024-04-28 20:00:00+06\\")","(58,\\"2024-04-28 20:02:00+06\\")","(59,\\"2024-04-28 20:04:00+06\\")","(60,\\"2024-04-28 20:06:00+06\\")","(61,\\"2024-04-28 20:08:00+06\\")","(62,\\"2024-04-28 20:10:00+06\\")","(63,\\"2024-04-28 20:12:00+06\\")","(70,\\"2024-04-28 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	polash	nazmul	f	zahir53	t
4113	2024-04-28 12:15:00+06	1	morning	{"(1,\\"2024-04-28 12:15:00+06\\")","(2,\\"2024-04-28 12:18:00+06\\")","(3,\\"2024-04-28 12:20:00+06\\")","(4,\\"2024-04-28 12:23:00+06\\")","(5,\\"2024-04-28 12:26:00+06\\")","(6,\\"2024-04-28 12:29:00+06\\")","(7,\\"2024-04-28 12:49:00+06\\")","(8,\\"2024-04-28 12:51:00+06\\")","(9,\\"2024-04-28 12:53:00+06\\")","(10,\\"2024-04-28 12:55:00+06\\")","(11,\\"2024-04-28 12:58:00+06\\")","(70,\\"2024-04-28 13:05:00+06\\")"}	to_buet	Ba-85-4722	t	monu67	nazmul	f	farid99	t
4114	2024-04-28 19:40:00+06	1	afternoon	{"(1,\\"2024-04-28 19:40:00+06\\")","(2,\\"2024-04-28 19:47:00+06\\")","(3,\\"2024-04-28 19:50:00+06\\")","(4,\\"2024-04-28 19:52:00+06\\")","(5,\\"2024-04-28 19:54:00+06\\")","(6,\\"2024-04-28 20:06:00+06\\")","(7,\\"2024-04-28 20:09:00+06\\")","(8,\\"2024-04-28 20:12:00+06\\")","(9,\\"2024-04-28 20:15:00+06\\")","(10,\\"2024-04-28 20:18:00+06\\")","(11,\\"2024-04-28 20:21:00+06\\")","(70,\\"2024-04-28 20:24:00+06\\")"}	from_buet	Ba-93-6087	t	nazrul6	nazmul	f	kk47	t
4115	2024-04-28 23:30:00+06	7	evening	{"(50,\\"2024-04-28 23:30:00+06\\")","(51,\\"2024-04-28 23:38:00+06\\")","(52,\\"2024-04-28 23:40:00+06\\")","(53,\\"2024-04-28 23:42:00+06\\")","(54,\\"2024-04-28 23:44:00+06\\")","(55,\\"2024-04-28 23:46:00+06\\")","(56,\\"2024-04-28 23:48:00+06\\")","(57,\\"2024-04-28 23:50:00+06\\")","(58,\\"2024-04-28 23:52:00+06\\")","(59,\\"2024-04-28 23:54:00+06\\")","(60,\\"2024-04-28 23:56:00+06\\")","(61,\\"2024-04-28 23:58:00+06\\")","(62,\\"2024-04-28 00:00:00+06\\")","(63,\\"2024-04-28 00:02:00+06\\")","(70,\\"2024-04-28 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	masud84	nazmul	f	reyazul	t
4116	2024-04-28 12:40:00+06	3	morning	{"(17,\\"2024-04-28 12:40:00+06\\")","(18,\\"2024-04-28 12:42:00+06\\")","(19,\\"2024-04-28 12:44:00+06\\")","(20,\\"2024-04-28 12:46:00+06\\")","(21,\\"2024-04-28 12:48:00+06\\")","(22,\\"2024-04-28 12:50:00+06\\")","(23,\\"2024-04-28 12:52:00+06\\")","(24,\\"2024-04-28 12:54:00+06\\")","(25,\\"2024-04-28 12:57:00+06\\")","(26,\\"2024-04-28 13:00:00+06\\")","(70,\\"2024-04-28 13:15:00+06\\")"}	to_buet	Ba-17-3886	t	rashed3	nazmul	f	abdulbari4	t
4117	2024-04-28 19:40:00+06	3	afternoon	{"(17,\\"2024-04-28 19:40:00+06\\")","(18,\\"2024-04-28 19:55:00+06\\")","(19,\\"2024-04-28 19:58:00+06\\")","(20,\\"2024-04-28 20:00:00+06\\")","(21,\\"2024-04-28 20:02:00+06\\")","(22,\\"2024-04-28 20:04:00+06\\")","(23,\\"2024-04-28 20:06:00+06\\")","(24,\\"2024-04-28 20:08:00+06\\")","(25,\\"2024-04-28 20:10:00+06\\")","(26,\\"2024-04-28 20:12:00+06\\")","(70,\\"2024-04-28 20:14:00+06\\")"}	from_buet	Ba-12-8888	t	felicitades35	nazmul	f	rishisunak45	t
4118	2024-04-28 12:40:00+06	4	morning	{"(27,\\"2024-04-28 12:40:00+06\\")","(28,\\"2024-04-28 12:42:00+06\\")","(29,\\"2024-04-28 12:44:00+06\\")","(30,\\"2024-04-28 12:46:00+06\\")","(31,\\"2024-04-28 12:50:00+06\\")","(32,\\"2024-04-28 12:52:00+06\\")","(33,\\"2024-04-28 12:54:00+06\\")","(34,\\"2024-04-28 12:58:00+06\\")","(35,\\"2024-04-28 13:00:00+06\\")","(70,\\"2024-04-28 13:10:00+06\\")"}	to_buet	Ba-69-8288	t	galloway67	nazmul	f	dariengap30	t
4119	2024-04-28 23:30:00+06	8	evening	{"(64,\\"2024-04-28 23:30:00+06\\")","(65,\\"2024-04-28 23:45:00+06\\")","(66,\\"2024-04-28 23:48:00+06\\")","(67,\\"2024-04-28 23:51:00+06\\")","(68,\\"2024-04-28 23:54:00+06\\")","(69,\\"2024-04-28 23:57:00+06\\")","(70,\\"2024-04-28 00:00:00+06\\")"}	from_buet	Ba-19-0569	t	marufmorshed	nazmul	f	jamal7898	t
4120	2024-04-28 12:55:00+06	2	morning	{"(12,\\"2024-04-28 12:55:00+06\\")","(13,\\"2024-04-28 12:57:00+06\\")","(14,\\"2024-04-28 12:59:00+06\\")","(15,\\"2024-04-28 13:01:00+06\\")","(16,\\"2024-04-28 13:03:00+06\\")","(70,\\"2024-04-28 13:15:00+06\\")"}	to_buet	Ba-22-4326	t	aminhaque	nazmul	f	refugee23	t
4121	2024-04-28 19:40:00+06	2	afternoon	{"(12,\\"2024-04-28 19:40:00+06\\")","(13,\\"2024-04-28 19:52:00+06\\")","(14,\\"2024-04-28 19:54:00+06\\")","(15,\\"2024-04-28 19:57:00+06\\")","(16,\\"2024-04-28 20:00:00+06\\")","(70,\\"2024-04-28 20:03:00+06\\")"}	from_buet	Ba-69-8288	t	kamaluddin	nazmul	f	rgbmbrt	t
4122	2024-04-28 23:30:00+06	2	evening	{"(12,\\"2024-04-28 23:30:00+06\\")","(13,\\"2024-04-28 23:42:00+06\\")","(14,\\"2024-04-28 23:45:00+06\\")","(15,\\"2024-04-28 23:48:00+06\\")","(16,\\"2024-04-28 23:51:00+06\\")","(70,\\"2024-04-28 23:54:00+06\\")"}	from_buet	Ba-86-1841	t	altaf	nazmul	f	shamsul54	t
4123	2024-04-28 23:30:00+06	4	evening	{"(27,\\"2024-04-28 23:30:00+06\\")","(28,\\"2024-04-28 23:40:00+06\\")","(29,\\"2024-04-28 23:42:00+06\\")","(30,\\"2024-04-28 23:44:00+06\\")","(31,\\"2024-04-28 23:46:00+06\\")","(32,\\"2024-04-28 23:48:00+06\\")","(33,\\"2024-04-28 23:50:00+06\\")","(34,\\"2024-04-28 23:52:00+06\\")","(35,\\"2024-04-28 23:54:00+06\\")","(70,\\"2024-04-28 23:56:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	f	germs23	t
4125	2024-04-28 23:30:00+06	5	evening	{"(36,\\"2024-04-28 23:30:00+06\\")","(37,\\"2024-04-28 23:40:00+06\\")","(38,\\"2024-04-28 23:45:00+06\\")","(39,\\"2024-04-28 23:50:00+06\\")","(40,\\"2024-04-28 23:57:00+06\\")","(70,\\"2024-04-28 00:00:00+06\\")"}	from_buet	Ba-77-7044	t	galloway67	nazmul	f	ghioe22	t
4126	2024-04-28 19:40:00+06	5	afternoon	{"(36,\\"2024-04-28 19:40:00+06\\")","(37,\\"2024-04-28 19:50:00+06\\")","(38,\\"2024-04-28 19:55:00+06\\")","(39,\\"2024-04-28 20:00:00+06\\")","(40,\\"2024-04-28 20:07:00+06\\")","(70,\\"2024-04-28 20:10:00+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	f	mahbub777	t
4127	2024-04-28 23:30:00+06	1	evening	{"(1,\\"2024-04-28 23:30:00+06\\")","(2,\\"2024-04-28 23:37:00+06\\")","(3,\\"2024-04-28 23:40:00+06\\")","(4,\\"2024-04-28 23:42:00+06\\")","(5,\\"2024-04-28 23:44:00+06\\")","(6,\\"2024-04-28 23:56:00+06\\")","(7,\\"2024-04-28 23:59:00+06\\")","(8,\\"2024-04-28 00:02:00+06\\")","(9,\\"2024-04-28 00:05:00+06\\")","(10,\\"2024-04-28 00:08:00+06\\")","(11,\\"2024-04-28 00:11:00+06\\")","(70,\\"2024-04-28 00:14:00+06\\")"}	from_buet	Ba-48-5757	t	abdulkarim6	nazmul	f	siddiq2	t
4128	2024-04-28 12:10:00+06	8	morning	{"(64,\\"2024-04-28 12:10:00+06\\")","(65,\\"2024-04-28 12:13:00+06\\")","(66,\\"2024-04-28 12:18:00+06\\")","(67,\\"2024-04-28 12:20:00+06\\")","(68,\\"2024-04-28 12:22:00+06\\")","(69,\\"2024-04-28 12:25:00+06\\")","(70,\\"2024-04-28 12:40:00+06\\")"}	to_buet	Ba-17-2081	t	shafiqul	nazmul	f	sharif86r	t
4129	2024-04-28 19:40:00+06	8	afternoon	{"(64,\\"2024-04-28 19:40:00+06\\")","(65,\\"2024-04-28 19:55:00+06\\")","(66,\\"2024-04-28 19:58:00+06\\")","(67,\\"2024-04-28 20:01:00+06\\")","(68,\\"2024-04-28 20:04:00+06\\")","(69,\\"2024-04-28 20:07:00+06\\")","(70,\\"2024-04-28 20:10:00+06\\")"}	from_buet	Ba-71-7930	t	jahangir	nazmul	f	khairul	t
4130	2024-04-28 23:30:00+06	3	evening	{"(17,\\"2024-04-28 23:30:00+06\\")","(18,\\"2024-04-28 23:45:00+06\\")","(19,\\"2024-04-28 23:48:00+06\\")","(20,\\"2024-04-28 23:50:00+06\\")","(21,\\"2024-04-28 23:52:00+06\\")","(22,\\"2024-04-28 23:54:00+06\\")","(23,\\"2024-04-28 23:56:00+06\\")","(24,\\"2024-04-28 23:58:00+06\\")","(25,\\"2024-04-28 00:00:00+06\\")","(26,\\"2024-04-28 00:02:00+06\\")","(70,\\"2024-04-28 00:04:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81	t
4131	2024-04-28 19:40:00+06	4	afternoon	{"(27,\\"2024-04-28 19:40:00+06\\")","(28,\\"2024-04-28 19:50:00+06\\")","(29,\\"2024-04-28 19:52:00+06\\")","(30,\\"2024-04-28 19:54:00+06\\")","(31,\\"2024-04-28 19:56:00+06\\")","(32,\\"2024-04-28 19:58:00+06\\")","(33,\\"2024-04-28 20:00:00+06\\")","(34,\\"2024-04-28 20:02:00+06\\")","(35,\\"2024-04-28 20:04:00+06\\")","(70,\\"2024-04-28 20:06:00+06\\")"}	from_buet	BA-01-2345	t	ibrahim	nazmul	f	greece01	t
4132	2024-04-29 23:30:00+06	6	evening	{"(41,\\"2024-04-29 23:30:00+06\\")","(42,\\"2024-04-29 23:46:00+06\\")","(43,\\"2024-04-29 23:48:00+06\\")","(44,\\"2024-04-29 23:50:00+06\\")","(45,\\"2024-04-29 23:52:00+06\\")","(46,\\"2024-04-29 23:54:00+06\\")","(47,\\"2024-04-29 23:56:00+06\\")","(48,\\"2024-04-29 23:58:00+06\\")","(49,\\"2024-04-29 00:00:00+06\\")","(70,\\"2024-04-29 00:02:00+06\\")"}	from_buet	Ba-83-8014	t	altaf78	nazmul	f	mahabhu	t
4133	2024-04-29 12:40:00+06	6	morning	{"(41,\\"2024-04-29 12:40:00+06\\")","(42,\\"2024-04-29 12:42:00+06\\")","(43,\\"2024-04-29 12:45:00+06\\")","(44,\\"2024-04-29 12:47:00+06\\")","(45,\\"2024-04-29 12:49:00+06\\")","(46,\\"2024-04-29 12:51:00+06\\")","(47,\\"2024-04-29 12:52:00+06\\")","(48,\\"2024-04-29 12:53:00+06\\")","(49,\\"2024-04-29 12:54:00+06\\")","(70,\\"2024-04-29 13:10:00+06\\")"}	to_buet	Ba-97-6734	t	shahid88	nazmul	f	azim990	t
4134	2024-04-29 19:40:00+06	6	afternoon	{"(41,\\"2024-04-29 19:40:00+06\\")","(42,\\"2024-04-29 19:56:00+06\\")","(43,\\"2024-04-29 19:58:00+06\\")","(44,\\"2024-04-29 20:00:00+06\\")","(45,\\"2024-04-29 20:02:00+06\\")","(46,\\"2024-04-29 20:04:00+06\\")","(47,\\"2024-04-29 20:06:00+06\\")","(48,\\"2024-04-29 20:08:00+06\\")","(49,\\"2024-04-29 20:10:00+06\\")","(70,\\"2024-04-29 20:12:00+06\\")"}	from_buet	Ba-36-1921	t	imranhashmi	nazmul	f	siam34	t
4135	2024-04-29 12:40:00+06	7	morning	{"(50,\\"2024-04-29 12:40:00+06\\")","(51,\\"2024-04-29 12:42:00+06\\")","(52,\\"2024-04-29 12:43:00+06\\")","(53,\\"2024-04-29 12:46:00+06\\")","(54,\\"2024-04-29 12:47:00+06\\")","(55,\\"2024-04-29 12:48:00+06\\")","(56,\\"2024-04-29 12:50:00+06\\")","(57,\\"2024-04-29 12:52:00+06\\")","(58,\\"2024-04-29 12:53:00+06\\")","(59,\\"2024-04-29 12:54:00+06\\")","(60,\\"2024-04-29 12:56:00+06\\")","(61,\\"2024-04-29 12:58:00+06\\")","(62,\\"2024-04-29 13:00:00+06\\")","(63,\\"2024-04-29 13:02:00+06\\")","(70,\\"2024-04-29 13:00:00+06\\")"}	to_buet	Ba-43-4286	t	nobiulnode	nazmul	f	mahmud64	t
4136	2024-04-29 19:40:00+06	7	afternoon	{"(50,\\"2024-04-29 19:40:00+06\\")","(51,\\"2024-04-29 19:48:00+06\\")","(52,\\"2024-04-29 19:50:00+06\\")","(53,\\"2024-04-29 19:52:00+06\\")","(54,\\"2024-04-29 19:54:00+06\\")","(55,\\"2024-04-29 19:56:00+06\\")","(56,\\"2024-04-29 19:58:00+06\\")","(57,\\"2024-04-29 20:00:00+06\\")","(58,\\"2024-04-29 20:02:00+06\\")","(59,\\"2024-04-29 20:04:00+06\\")","(60,\\"2024-04-29 20:06:00+06\\")","(61,\\"2024-04-29 20:08:00+06\\")","(62,\\"2024-04-29 20:10:00+06\\")","(63,\\"2024-04-29 20:12:00+06\\")","(70,\\"2024-04-29 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	polash	nazmul	f	zahir53	t
4137	2024-04-29 12:15:00+06	1	morning	{"(1,\\"2024-04-29 12:15:00+06\\")","(2,\\"2024-04-29 12:18:00+06\\")","(3,\\"2024-04-29 12:20:00+06\\")","(4,\\"2024-04-29 12:23:00+06\\")","(5,\\"2024-04-29 12:26:00+06\\")","(6,\\"2024-04-29 12:29:00+06\\")","(7,\\"2024-04-29 12:49:00+06\\")","(8,\\"2024-04-29 12:51:00+06\\")","(9,\\"2024-04-29 12:53:00+06\\")","(10,\\"2024-04-29 12:55:00+06\\")","(11,\\"2024-04-29 12:58:00+06\\")","(70,\\"2024-04-29 13:05:00+06\\")"}	to_buet	Ba-85-4722	t	monu67	nazmul	f	farid99	t
4138	2024-04-29 19:40:00+06	1	afternoon	{"(1,\\"2024-04-29 19:40:00+06\\")","(2,\\"2024-04-29 19:47:00+06\\")","(3,\\"2024-04-29 19:50:00+06\\")","(4,\\"2024-04-29 19:52:00+06\\")","(5,\\"2024-04-29 19:54:00+06\\")","(6,\\"2024-04-29 20:06:00+06\\")","(7,\\"2024-04-29 20:09:00+06\\")","(8,\\"2024-04-29 20:12:00+06\\")","(9,\\"2024-04-29 20:15:00+06\\")","(10,\\"2024-04-29 20:18:00+06\\")","(11,\\"2024-04-29 20:21:00+06\\")","(70,\\"2024-04-29 20:24:00+06\\")"}	from_buet	Ba-93-6087	t	nazrul6	nazmul	f	kk47	t
4139	2024-04-29 23:30:00+06	7	evening	{"(50,\\"2024-04-29 23:30:00+06\\")","(51,\\"2024-04-29 23:38:00+06\\")","(52,\\"2024-04-29 23:40:00+06\\")","(53,\\"2024-04-29 23:42:00+06\\")","(54,\\"2024-04-29 23:44:00+06\\")","(55,\\"2024-04-29 23:46:00+06\\")","(56,\\"2024-04-29 23:48:00+06\\")","(57,\\"2024-04-29 23:50:00+06\\")","(58,\\"2024-04-29 23:52:00+06\\")","(59,\\"2024-04-29 23:54:00+06\\")","(60,\\"2024-04-29 23:56:00+06\\")","(61,\\"2024-04-29 23:58:00+06\\")","(62,\\"2024-04-29 00:00:00+06\\")","(63,\\"2024-04-29 00:02:00+06\\")","(70,\\"2024-04-29 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	masud84	nazmul	f	reyazul	t
4140	2024-04-29 12:40:00+06	3	morning	{"(17,\\"2024-04-29 12:40:00+06\\")","(18,\\"2024-04-29 12:42:00+06\\")","(19,\\"2024-04-29 12:44:00+06\\")","(20,\\"2024-04-29 12:46:00+06\\")","(21,\\"2024-04-29 12:48:00+06\\")","(22,\\"2024-04-29 12:50:00+06\\")","(23,\\"2024-04-29 12:52:00+06\\")","(24,\\"2024-04-29 12:54:00+06\\")","(25,\\"2024-04-29 12:57:00+06\\")","(26,\\"2024-04-29 13:00:00+06\\")","(70,\\"2024-04-29 13:15:00+06\\")"}	to_buet	Ba-17-3886	t	rashed3	nazmul	f	abdulbari4	t
4141	2024-04-29 19:40:00+06	3	afternoon	{"(17,\\"2024-04-29 19:40:00+06\\")","(18,\\"2024-04-29 19:55:00+06\\")","(19,\\"2024-04-29 19:58:00+06\\")","(20,\\"2024-04-29 20:00:00+06\\")","(21,\\"2024-04-29 20:02:00+06\\")","(22,\\"2024-04-29 20:04:00+06\\")","(23,\\"2024-04-29 20:06:00+06\\")","(24,\\"2024-04-29 20:08:00+06\\")","(25,\\"2024-04-29 20:10:00+06\\")","(26,\\"2024-04-29 20:12:00+06\\")","(70,\\"2024-04-29 20:14:00+06\\")"}	from_buet	Ba-12-8888	t	felicitades35	nazmul	f	rishisunak45	t
4142	2024-04-29 12:40:00+06	4	morning	{"(27,\\"2024-04-29 12:40:00+06\\")","(28,\\"2024-04-29 12:42:00+06\\")","(29,\\"2024-04-29 12:44:00+06\\")","(30,\\"2024-04-29 12:46:00+06\\")","(31,\\"2024-04-29 12:50:00+06\\")","(32,\\"2024-04-29 12:52:00+06\\")","(33,\\"2024-04-29 12:54:00+06\\")","(34,\\"2024-04-29 12:58:00+06\\")","(35,\\"2024-04-29 13:00:00+06\\")","(70,\\"2024-04-29 13:10:00+06\\")"}	to_buet	Ba-69-8288	t	galloway67	nazmul	f	dariengap30	t
4143	2024-04-29 23:30:00+06	8	evening	{"(64,\\"2024-04-29 23:30:00+06\\")","(65,\\"2024-04-29 23:45:00+06\\")","(66,\\"2024-04-29 23:48:00+06\\")","(67,\\"2024-04-29 23:51:00+06\\")","(68,\\"2024-04-29 23:54:00+06\\")","(69,\\"2024-04-29 23:57:00+06\\")","(70,\\"2024-04-29 00:00:00+06\\")"}	from_buet	Ba-19-0569	t	marufmorshed	nazmul	f	jamal7898	t
4144	2024-04-29 12:55:00+06	2	morning	{"(12,\\"2024-04-29 12:55:00+06\\")","(13,\\"2024-04-29 12:57:00+06\\")","(14,\\"2024-04-29 12:59:00+06\\")","(15,\\"2024-04-29 13:01:00+06\\")","(16,\\"2024-04-29 13:03:00+06\\")","(70,\\"2024-04-29 13:15:00+06\\")"}	to_buet	Ba-22-4326	t	aminhaque	nazmul	f	refugee23	t
4145	2024-04-29 19:40:00+06	2	afternoon	{"(12,\\"2024-04-29 19:40:00+06\\")","(13,\\"2024-04-29 19:52:00+06\\")","(14,\\"2024-04-29 19:54:00+06\\")","(15,\\"2024-04-29 19:57:00+06\\")","(16,\\"2024-04-29 20:00:00+06\\")","(70,\\"2024-04-29 20:03:00+06\\")"}	from_buet	Ba-69-8288	t	kamaluddin	nazmul	f	rgbmbrt	t
4146	2024-04-29 23:30:00+06	2	evening	{"(12,\\"2024-04-29 23:30:00+06\\")","(13,\\"2024-04-29 23:42:00+06\\")","(14,\\"2024-04-29 23:45:00+06\\")","(15,\\"2024-04-29 23:48:00+06\\")","(16,\\"2024-04-29 23:51:00+06\\")","(70,\\"2024-04-29 23:54:00+06\\")"}	from_buet	Ba-86-1841	t	altaf	nazmul	f	shamsul54	t
4147	2024-04-29 23:30:00+06	4	evening	{"(27,\\"2024-04-29 23:30:00+06\\")","(28,\\"2024-04-29 23:40:00+06\\")","(29,\\"2024-04-29 23:42:00+06\\")","(30,\\"2024-04-29 23:44:00+06\\")","(31,\\"2024-04-29 23:46:00+06\\")","(32,\\"2024-04-29 23:48:00+06\\")","(33,\\"2024-04-29 23:50:00+06\\")","(34,\\"2024-04-29 23:52:00+06\\")","(35,\\"2024-04-29 23:54:00+06\\")","(70,\\"2024-04-29 23:56:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	f	germs23	t
4148	2024-04-29 12:30:00+06	5	morning	{"(36,\\"2024-04-29 12:30:00+06\\")","(37,\\"2024-04-29 12:33:00+06\\")","(38,\\"2024-04-29 12:40:00+06\\")","(39,\\"2024-04-29 12:45:00+06\\")","(40,\\"2024-04-29 12:50:00+06\\")","(70,\\"2024-04-29 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	nizam88	nazmul	f	rashid56	t
4149	2024-04-29 23:30:00+06	5	evening	{"(36,\\"2024-04-29 23:30:00+06\\")","(37,\\"2024-04-29 23:40:00+06\\")","(38,\\"2024-04-29 23:45:00+06\\")","(39,\\"2024-04-29 23:50:00+06\\")","(40,\\"2024-04-29 23:57:00+06\\")","(70,\\"2024-04-29 00:00:00+06\\")"}	from_buet	Ba-77-7044	t	galloway67	nazmul	f	ghioe22	t
4150	2024-04-29 19:40:00+06	5	afternoon	{"(36,\\"2024-04-29 19:40:00+06\\")","(37,\\"2024-04-29 19:50:00+06\\")","(38,\\"2024-04-29 19:55:00+06\\")","(39,\\"2024-04-29 20:00:00+06\\")","(40,\\"2024-04-29 20:07:00+06\\")","(70,\\"2024-04-29 20:10:00+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	f	mahbub777	t
4151	2024-04-29 23:30:00+06	1	evening	{"(1,\\"2024-04-29 23:30:00+06\\")","(2,\\"2024-04-29 23:37:00+06\\")","(3,\\"2024-04-29 23:40:00+06\\")","(4,\\"2024-04-29 23:42:00+06\\")","(5,\\"2024-04-29 23:44:00+06\\")","(6,\\"2024-04-29 23:56:00+06\\")","(7,\\"2024-04-29 23:59:00+06\\")","(8,\\"2024-04-29 00:02:00+06\\")","(9,\\"2024-04-29 00:05:00+06\\")","(10,\\"2024-04-29 00:08:00+06\\")","(11,\\"2024-04-29 00:11:00+06\\")","(70,\\"2024-04-29 00:14:00+06\\")"}	from_buet	Ba-48-5757	t	abdulkarim6	nazmul	f	siddiq2	t
4152	2024-04-29 12:10:00+06	8	morning	{"(64,\\"2024-04-29 12:10:00+06\\")","(65,\\"2024-04-29 12:13:00+06\\")","(66,\\"2024-04-29 12:18:00+06\\")","(67,\\"2024-04-29 12:20:00+06\\")","(68,\\"2024-04-29 12:22:00+06\\")","(69,\\"2024-04-29 12:25:00+06\\")","(70,\\"2024-04-29 12:40:00+06\\")"}	to_buet	Ba-17-2081	t	shafiqul	nazmul	f	sharif86r	t
4153	2024-04-29 19:40:00+06	8	afternoon	{"(64,\\"2024-04-29 19:40:00+06\\")","(65,\\"2024-04-29 19:55:00+06\\")","(66,\\"2024-04-29 19:58:00+06\\")","(67,\\"2024-04-29 20:01:00+06\\")","(68,\\"2024-04-29 20:04:00+06\\")","(69,\\"2024-04-29 20:07:00+06\\")","(70,\\"2024-04-29 20:10:00+06\\")"}	from_buet	Ba-71-7930	t	jahangir	nazmul	f	khairul	t
4154	2024-04-29 23:30:00+06	3	evening	{"(17,\\"2024-04-29 23:30:00+06\\")","(18,\\"2024-04-29 23:45:00+06\\")","(19,\\"2024-04-29 23:48:00+06\\")","(20,\\"2024-04-29 23:50:00+06\\")","(21,\\"2024-04-29 23:52:00+06\\")","(22,\\"2024-04-29 23:54:00+06\\")","(23,\\"2024-04-29 23:56:00+06\\")","(24,\\"2024-04-29 23:58:00+06\\")","(25,\\"2024-04-29 00:00:00+06\\")","(26,\\"2024-04-29 00:02:00+06\\")","(70,\\"2024-04-29 00:04:00+06\\")"}	from_buet	Ba-34-7413	t	fazlu77	nazmul	f	nasir81	t
4155	2024-04-29 19:40:00+06	4	afternoon	{"(27,\\"2024-04-29 19:40:00+06\\")","(28,\\"2024-04-29 19:50:00+06\\")","(29,\\"2024-04-29 19:52:00+06\\")","(30,\\"2024-04-29 19:54:00+06\\")","(31,\\"2024-04-29 19:56:00+06\\")","(32,\\"2024-04-29 19:58:00+06\\")","(33,\\"2024-04-29 20:00:00+06\\")","(34,\\"2024-04-29 20:02:00+06\\")","(35,\\"2024-04-29 20:04:00+06\\")","(70,\\"2024-04-29 20:06:00+06\\")"}	from_buet	BA-01-2345	t	ibrahim	nazmul	f	greece01	t
\.


--
-- Data for Name: assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.assignment (id, route, bus, driver, helper, valid, start_time, end_time, shift) FROM stdin;
\.


--
-- Data for Name: broadcast_notification; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.broadcast_notification (id, body, "timestamp", title) FROM stdin;
26	2024-04-23 13:52:25	2024-04-23 13:52:27.344703+06	Afternoon buses will start at 2pm today.
27	2024-04-23 14:09:44	2024-04-23 14:09:46.524641+06	Bus service is suspended next Saturday
28	no bus available tomorrow \nSent on: 4/23/2024, 4:27:46 PM	2024-04-23 16:27:46.900315+06	unavailabe
29	Thank you \nSent on: 4/26/2024, 8:02:52 PM	2024-04-26 20:02:52.879511+06	This is your daily reminder that Ikhtiyar Uddin Muhammad bin Bakhtiyar Khilji ইখতিয়ার উদ্দিন মুহম্মদ বিন বখতিয়ার খিলজী was a Turkic military general of Qutb-ud-din Aybak. 
30	Turkic military general of Qutb-ud-din Aybak. \nSent on: 4/26/2024, 8:05:01 PM	2024-04-26 20:05:02.566836+06	ইখতিয়ার উদ্দিন মুহম্মদ বিন বখতিয়ার খিলজী
31	2024-04-26 21:21:50	2024-04-26 21:21:53.033519+06	ন'টিফিকে'ছ'ন
32	onek boro bncd	2024-04-26 21:22:55.3546+06	jll bncd
\.


--
-- Data for Name: buet_staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buet_staff (id, name, department, designation, residence, password, phone, valid, pending, service) FROM stdin;
pranto	Md. Toufikuzzaman	CSE	Lecturer	Guwahati	$2a$12$moUka1mC52nCG7y1chEJH.aRJjSTT28AjJlTu3AE7QvrLeAe07NJC	01794316176	t	5000	f
mashiat	Mashiat Mustaq	CSE	Lecturer	Kallyanpur	$2a$12$VA1Ffp.8bQxwb31j4uGyrOLPmMFV9aLbfDyePOb4JyddnU3jI6tDm	01234567890	t	400	t
rayhan	Rayhan Rashed	CSE	Lecturer	Mohammadpur	$2a$12$Jx5HtdLxU7AbC1A4woVma.Lxb/so.AXAkLcyFxre8XquWlGkuw4EC	01234567890	t	400	t
fahim	Sheikh Azizul Hakim	CSE	Lecturer	Demra	$2a$12$5WeTox.wKCUYbABO8YVXu.SMYS75PeUylE/s/gm90Gf5ZduNd.jp.	01911302328	t	600	t
jawad	Jawad Ul Alam	EEE	Lecturer	Nakhalpara	$2a$12$7amLXXhSxnw2NRv.AcMrKOEyLHepx8PSw7SpSeART.I.WEjfyy6rG	01633197399	t	800	t
younus	Junayed Younus Khan	CSE	Professor	Teachers' Quarter	$2a$12$weSHv8XdkPsuJxDDZ6CpEOvSIe43.oxsxArDPVamLwtg2ua1IC5GS	01234567890	t	600	t
mrinmoy	Mrinmoy Kundu	EEE	Lecturer	Khilgaon	$2a$12$3FdSJGqgzpTBwuRPSctBWuMp/XIqMB/yUc.4yjy7qvWZ83b/HFYEC	01637927525	t	4000	t
sayem	Sayem Hasan	CSE	Lecturer	Basabo	$2a$12$WBEXHaoMcQ.c/ivn8fFIXeGkwB9oDYzu.HFfWcwj89mi.90PdjcNO	01626187505	t	0	f
\.


--
-- Data for Name: buet_staff_feedback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buet_staff_feedback (id, complainer_id, route, submission_timestamp, concerned_timestamp, text, trip_id, subject, response, valid) FROM stdin;
45	pranto	3	2024-01-24 07:59:49.727805+06	2024-01-23 00:00:00+06	nsns	\N	{bus}	\N	t
53	pranto	8	2024-02-08 23:22:19.613093+06	2024-02-07 00:00:00+06	\r\nThe staff behavior was very rude and they were very disrespectful towards the passengers, which significantly tarnished the overall experience of the journey. Additionally, their lack of professionalism and disregard for customer satisfaction left much to be desired. Such behavior not only creates discomfort but also undermines the reputation of the service provider. It is essential for the staff to exhibit courteousness and respect towards passengers, fostering a positive and welcoming environment for all travelers.	\N	{staff,driver}	\N	t
58	pranto	5	2024-03-04 14:23:32.950118+06	2024-03-02 00:00:00+06	A bad experience.	\N	{staff}	\N	t
46	pranto	3	2024-01-24 11:38:25.472839+06	2024-01-25 00:00:00+06	hsjsj	\N	{driver}	Your feedback is being processed	t
\.


--
-- Data for Name: bus; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bus (reg_id, type, capacity, remarks, valid, photo) FROM stdin;
BA-01-2345	single_decker	30	Imported from Japan	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-12-8888	mini	60	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-17-2081	double_decker	100	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-17-3886	double_decker	100	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-19-0569	double_decker	69	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-20-3066	normal	60	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-22-4326	mini	30	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-24-8518	double_decker	100	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-34-7413	mini	30	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-35-1461	normal	60	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-36-1921	normal	60	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-43-4286	mini	30	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-46-1334	mini	30	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-48-5757	mini	30	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-63-1146	double_decker	100	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-69-8288	double_decker	60	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-71-7930	mini	30	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-77-7044	mini	30	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-83-8014	mini	30	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-85-4722	normal	60	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-86-1841	normal	60	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-93-6087	mini	30	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-97-6734	mini	30	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
Ba-98-5568	mini	30	\N	t	https://i.postimg.cc/28fbryn2/bus.jpg
BA-11-1234	mini	13		t	\N
\.


--
-- Data for Name: bus_staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bus_staff (id, phone, password, role, name, valid, start_date, end_date) FROM stdin;
felicitades35	01869465773	$2a$12$QXojv2Qi5JWbnHqlXVJ/iOsY5ek1ZzEd8aU7TxvgI0SLHLLebz9su	driver	Matty Parker	t	\N	\N
mahmud64	01328226564	$2a$12$LeFqDxpS9CtUIHMP4NPPLugvhvXt5oZ6f15gWb1d9pk0lB1tjccRW	collector	Mahmudul Hasan	t	\N	\N
shamsul54	01595195413	$2a$12$RLObtVZ.3EQpZy8mEa9Y0.sh6XaFf7sNtLPSc1TWiTBLTQs1G3Zei	collector	Shamsul Islam	t	\N	\N
abdulbari4	01317233333	$2a$12$zi0o5eouMqUWrVZFP42pk.AS9NoG5q37Ps0y93DZCGXE0Y39Eh436	collector	Abdul Bari	t	\N	\N
ASADUZZAMAN	01767495642	$2a$12$NdfLbp1kT8XdXhJJlQ8B0u/47ceKdUGabS6bWRK94Rb1wwvpBm0KW	collector	Asaduzzaman	t	\N	\N
farid99	01835421047	$2a$12$1FgwdZaeUjwy54/s7rgTt.3jpG78CWoc15VoatWk4HF73kYPckDYm	collector	Farid Uddin	t	\N	\N
zahir53	01445850507	$2a$12$D98aELlvMcT1MSCLgiA4bOJyR3N8GTA6c68oH6ZLdpru0rCTjeYx.	collector	Zahirul Islam	t	\N	\N
jamal7898	01308831356	$2a$12$f0dp5gnOaLtA3PHSwmDjFODI3gvdI8eywRyAeOZh5vkKnFKd4sq7u	collector	Jamal Uddin	t	\N	\N
alamgir	01724276193	$2a$12$Mks0vq8VnFE0KQLPPGDHIOckNk0X/Bg0t8ZZY94TBOdUNNFhiVYpa	collector	Alamgir Hossain	t	\N	\N
sohel55	01913144741	$2a$12$i3pmxyB.s/IBCoaAFIrUSeD09geAIbQHBTJ4qXzqfM4xt7U5MbnYq	driver	Sohel Mia	t	\N	\N
galloway67	01736449223	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	driver	George Conway	t	\N	\N
arif43	01717596989	$2a$12$QXojv2Qi5JWbnHqlXVJ/iOsY5ek1ZzEd8aU7TxvgI0SLHLLebz9su	driver	Arif Hossain	t	\N	\N
azim990	01731184023	$2a$12$OO/7cjbe4RzN46d9fPsVjefASRLtdnNbPuX1AIW3Ant6abmcJJndG	collector	Azim Ahmed	t	\N	\N
altaf78	01711840323	$2a$12$dbWCKqB4wW1.7dOJzjD4EOzVUjBptKXP96WOMEbz2GjQtaqB1Whae	driver	Altaf Mia	t	\N	\N
reyazul	01521564738	$2a$12$pXPW0EWH9ZGeeaGkqGsgaOWbtiaGU77lbd6ClXl29W0YERI5aISWe	collector	Kazi Rreyazul	t	\N	\N
ibrahim	01345435435	$2a$12$6Doi584t7hqxuKy0wARppOK8HR0iyfpP4Uug1rXrubn4F.XMxKdIa	driver	Khondker Ibrahim	t	\N	\N
rahmatullah	01747457646	$2a$12$d/lXs/rJ4QNdctxyii.HJeB91Udj9KMD/mxieQCKJIk8EsUZ1iyjm	driver	Hazi Rahmatullah	t	\N	\N
monu67	01345678902	$2a$12$2Wky7R.kBFFcbFmICBBrle1ePIJsSGiddsKXjUuJao4QWcGKuzJUC	driver	Monu Mia	t	\N	\N
polash	01678923456	$2a$12$ShQOKnRZvD4GW0y7CBKZjuckou.JHsGuZQMxqWC1/mEqIgg539vJe	driver	Polash Sikder	t	\N	\N
nizam88	01589742446	$2a$12$/VqawsZWgybw6H5TzKiNHukVK8Irl6bvh9jPEonLrOzqOx1wIdRj2	driver	Nizamuddin Ahmed	t	\N	\N
kamaluddin	01764619110	$2a$12$fQMqPhKHPiUZzJVudN8NfeBlUijPF1BWTf3wG2sZmeOa8om5NrVaS	driver	Kamal Uddin	t	\N	\N
shafiqul	01590909583	$2a$12$VghRKN9mDuPmugby/FlLteeXh0o9ADCUUzKzvMNYW.saZcJyJCHHi	driver	Shafiqul Islam	t	\N	\N
abdulkarim6	01653913218	$2a$12$XZ6W.7npe4btQ2Sb9.MZLel0Tm19UEQiu8mGimcpwSZq5gxEgRGcK	driver	Abdul Karim	t	\N	\N
imranhashmi	01826020989	$2a$12$vMt9Ace7ZQVOVwz/GlCudeO7nsGu.BbnMhJYtQIHyAEO1k/R2lE2q	driver	Imran Khan	t	\N	\N
jahangir	01593143605	$2a$12$5yxa3ETfLnja1PLWozr0jOUMtLEcejixzF6Ipcu3OI1wVxFHMmAES	driver	Jahangir Alam	t	\N	\N
rashed3	01410038120	$2a$12$W0aYTqNWuVIqISl9KnTEiu/am359ekUHnPp1uhuBT.NEf4R4ktOeu	driver	Rashedul Haque	t	\N	\N
nazrul6	01699974102	$2a$12$qrAfe1coHKyu1eXjbbNyyOoyuEtn3TDAhz9CqtD6isQmhOGAW2M0S	driver	Nazrul Islam	t	\N	\N
rashid56	01719898746	$2a$12$/M1gpTDTW1CuI8FUm5bLu.JDb/uzkM4Hjm0jedZzYeH7784kFdd5a	collector	Rashidul Haque	t	\N	\N
sharif86r	01405293626	$2a$12$rsIzJ3Z7GVq3aBCXvV4DR.DviJjofzQvbnqouQxfNgdDSaPal3dKi	collector	Sharif Ahmed	t	\N	\N
mahbub777	01987835715	$2a$12$f.x9rAKZq3MGyzf2gaK3J.huUgzPe6LryMtCGXnX7eHD8tvnr1REa	collector	Mahbubur Rahman	t	\N	\N
khairul	01732238594	$2a$12$8v5WT0tV.xusChomV33rWu4orPcFqUTA6vzR13c4t/b0Qj9ktNKEW	collector	Khairul Hasan	t	\N	\N
siddiq2	01451355422	$2a$12$EiyVFWdeSzBbMWESfoMdCeHsAubI3FkppfJ6Rt8xTSt2ZpmvxUtyu	collector	Siddiqur Rahman	t	\N	\N
nasir81	01481194926	$2a$12$Y0FGv2TXIJlVCChaRRvtf.T9Q3jaXZcQhAie4d1vKtDPSaWwZopFa	collector	Nasir Uddin	t	\N	\N
masud84	01333694280	$2a$12$cZurgNcIGXe4gqk0sUfjZ.SSB//kRpLd6J5LElSo8ZUck2qOR.xo2	driver	Masudur Rahman	t	2024-03-03 00:00:00+06	2024-03-05 00:00:00+06
rafiqul	01624582525	$2a$12$scfPmCg7cWkNgdqXyHbbcOMb63sevkjnRfvQstfD7UbVwANrCes..	driver	Rafiqul Hasan	t	2024-03-02 00:00:00+06	2024-03-04 00:00:00+06
aminhaque	01623557727	$2a$12$qjHfLEK4l4jhWRdmTrpIVuYLtQ8xbmVvus9u49RvlLmLXsZTdP1S.	driver	Aminul Haque	t	2024-03-02 00:00:00+06	2024-03-05 00:00:00+06
marufmorshed	01245364478	$2a$12$6Doi584t7hqxuKy0wARppOK8HR0iyfpP4Uug1rXrubn4F.XMxKdIa	driver	Sayeed Maruf Morshed	t	\N	\N
siam34	01564726883	$2a$12$RLObtVZ.3EQpZy8mEa9Y0.sh6XaFf7sNtLPSc1TWiTBLTQs1G3Zei	collector	Siam Chowdhury	t	\N	\N
izdn56	01560384923	$2a$12$RLObtVZ.3EQpZy8mEa9Y0.sh6XaFf7sNtLPSc1TWiTBLTQs1G3Zei	collector	Zidan Redwan	t	\N	\N
azwad00	01768394263	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	driver	Azwad Abrar	t	\N	\N
buenos43	01245351786	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	driver	Buenas Tardes	t	\N	\N
dariengap30	01308263356	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	collector	Shahidul Islam	t	\N	\N
germs23	01308831356	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	collector	Farhan Hossain	t	\N	\N
shahid88	01721202729	$2a$12$LBjDsiOlXyGehr0SB99Bp.r7MJl4rUUmHzoXJDpRYdtk2LKFgOexW	driver	Shahid Khan	t	2024-03-02 00:00:00+06	2024-03-07 00:00:00+06
altaf	01933002212	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	driver	Altaf Hossain	t	\N	\N
fazlu77	01846939488	$2a$12$bvimHRtXKtdNvntiFID6kuIZQrPM9alZ6seeB5JdVGE396NM44X4O	driver	Fazlur Rahman	t	2024-04-11 00:00:00+06	2024-04-26 00:00:00+06
ghioe22	01308666666	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	collector	Abdul Rahman	t	\N	\N
greece01	01999831356	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	collector	Mohammad Ali	t	\N	\N
kk47	01308831356	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	collector	Nazmul Hasan	t	\N	\N
mahabhu	01646168292	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	collector	Code Forcesuz Zaman	t	\N	\N
nobiulnode	01435267392	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	driver	Nobule Hoque	t	\N	\N
refugee23	01458831356	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	collector	Mustafa Kamal	t	\N	\N
rgbmbrt	01554662773	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	collector	Ragib Mobarat	t	\N	\N
rishisunak45	01308831345	$2a$12$jTNh5YL2Dv0J8IVRysMOj.nc6K7x5DbqaQl.NIw94WODwrlOt/OHW	collector	Saifuddin Ahmed	t	\N	\N
\.


--
-- Data for Name: inventory; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventory (id, name, amount, rate, valid, pdate) FROM stdin;
02920caa	Floor Mats	31	3750	t	2024-02-01
1a9fc496	Air Filter	20	2500	t	2024-02-01
1bab219c	Radiator	12	16250	t	2024-02-01
1ef1b698	Mirror	19	5625	t	2024-02-12
242cec9c	Battery	29	12500	t	2024-02-01
488159f6	Windshield Wipers	31	2500	t	2024-02-17
63c98708	Headlights	43	10000	t	2023-09-01
75fca14e	Exhaust	10	18750	t	2024-02-01
7dd7c1bc	Seat Cover	33	3125	t	2024-02-01
8a771691	Taillights	2	7500	t	2024-01-05
a3e0df84	Coolant	0	3500	t	2024-02-23
affa3946	Oil Filter	35	1875	t	2024-02-01
b7ba242a	Screwdriver Set	8	3125	t	2024-02-01
b9270940	Brake Fluid	23	2750	t	2023-02-01
b9f15218	Wrench Set	40	5000	t	2024-02-01
bce87b3a	Engine Oil	7	6250	t	2023-02-11
de516ae6	Steering Wheel Cover	31	2500	t	2024-02-01
f54b800a	Brake Pad	17	4375	t	2024-02-01
3115dd36	Transmission Fluid	26	3750	t	2023-10-01
5b633ff1	Tire	14	15000	t	2024-02-01
19ce9e76	Fuel Pump	21	17500	t	2024-03-02
\.


--
-- Data for Name: notice; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notice (id, text, date) FROM stdin;
13	Buses will start at 7 am for ramadan. Till 27th ramadan.	2024-03-04 12:56:22.005+06
14	hello	2024-03-04 15:39:56.119+06
15	Mohammadpur route -1 will now stop at 9 no. road instead of police station	2024-04-23 13:57:11.345+06
\.


--
-- Data for Name: personal_notification; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.personal_notification (id, body, "timestamp", title, user_id) FROM stdin;
1	notif for glob only	2024-02-16 14:26:32.68593+06	Hi glob	1905084
2	notif for glob only	2024-02-16 14:28:38.606055+06	Hi glob	1905084
3	notif for glob only	2024-02-16 14:30:17.758981+06	Hi glob	1905084
4	notif for GLOBy	2024-02-16 14:31:10.027519+06	Hiiii bogm	1905084
5	notif for GLOB again but fg	2024-02-16 14:31:42.369521+06	Hiiii bogm fg	1905084
6	lol	2024-02-19 18:46:50.334007+06	test from nfu for cringe notification 	1905077
7	lol	2024-02-19 18:48:01.022982+06	test from nfu for cringe notification 	1905077
8	lol	2024-02-19 19:07:46.347467+06	test from nfu for cringe notification 	1905077
9	lol	2024-02-19 19:09:44.573911+06	test from nfu for cringe notification 	1905077
10	lol	2024-02-19 19:18:04.901293+06	test from nfu for cringe notification 	1905077
11	lol	2024-02-19 19:28:28.035994+06	test from nfu for cringe notification 	1905077
12	lol	2024-02-19 19:30:03.207696+06	test from nfu for cringe notification 	1905077
13	lol	2024-02-19 19:30:41.540695+06	test from nfu for cringe notification 	1905077
14	lol	2024-02-19 19:30:42.850095+06	test from nfu for cringe notification 	1905077
15	lol	2024-02-19 19:31:47.935233+06	test from nfu for cringe notification 	1905077
16	lol	2024-02-19 19:33:04.010689+06	test from nfu for cringe notification 	1905077
17	lol	2024-02-19 19:35:05.457521+06	test from nfu for cringe notification 	1905077
18	lol	2024-02-19 19:41:30.271856+06	test from nfu for cringe notification 	1905077
19	lol	2024-02-19 19:47:38.27996+06	test from nfu for cringe notification 	1905077
20	lol	2024-02-19 19:48:17.846027+06	test from nfu for cringe notification 	1905077
21	You have less than 10 tickets remaining. Please buy more tickets to continue using the bus service.	2024-02-19 20:18:28.291847+06	WARNING: Tickets running low!	1905077
22	Trip #6969 has crossed Mohammadpur Krishi Market and is approaching asad gate bus station	2024-02-19 20:21:08.922112+06	Your bus is very close to your stop.	1905077
23	You have been assigned this trip with bus Ba-48-5757 this shift afternoon on 2024-03-03.	2024-03-03 07:23:35.367128+06	New Trip Allocation	rashed3
24	You have been assigned this trip with bus Ba-48-5757 this shift afternoon on 2024-03-03.	2024-03-03 07:23:45.050909+06	New Trip Allocation	altaf
25	You have been assigned a trip with bus Ba-48-5757, shift afternoon on 2024-03-03.	2024-03-03 07:27:20.952426+06	New Trip Allocation	2634
26	You have been assigned a trip with bus Ba-48-5757, shift afternoon on 2024-03-03.	2024-03-03 07:27:37.028707+06	New Trip Allocation	2634
27	You have been assigned a trip with bus Ba-48-5757, shift afternoon on 2024-03-03. Staffs rashed3 and azim990.	2024-03-03 07:30:31.724088+06	New Trip Allocation	rashed3
28	You have been assigned a trip with bus Ba-48-5757, shift afternoon on 2024-03-03. Staffs rashed3 and azim990.	2024-03-03 07:30:32.060143+06	New Trip Allocation	azim990
29	You have been assigned a trip with bus Ba-48-5757, shift afternoon on 2024-03-03. Staffs altaf and azim990.	2024-03-03 07:30:47.901175+06	New Trip Allocation	altaf
30	You have been assigned a trip with bus Ba-48-5757, shift afternoon on 2024-03-03. Staffs altaf and azim990.	2024-03-03 07:30:48.238851+06	New Trip Allocation	azim990
31	You have been assigned a trip with bus Ba-19-0569, shift morning on 2024-03-03. Staffs altaf and jamal7898.	2024-03-03 08:15:28.80767+06	New Trip Allocation	altaf
32	You have been assigned a trip with bus Ba-19-0569, shift morning on 2024-03-03. Staffs altaf and jamal7898.	2024-03-03 08:15:29.141539+06	New Trip Allocation	jamal7898
33	You have been assigned a trip with bus Ba-19-0569, shift afternoon on 2024-03-03. Staffs polash and jamal7898.	2024-03-03 08:20:58.63492+06	New Trip Allocation	polash
34	You have been assigned a trip with bus Ba-19-0569, shift afternoon on 2024-03-03. Staffs polash and jamal7898.	2024-03-03 08:20:58.96892+06	New Trip Allocation	jamal7898
35	You have been assigned a trip with bus Ba-48-5757, shift afternoon on 2024-03-03. Staffs rashed3 and azim990.	2024-03-03 12:00:22.082243+06	New Trip Allocation	rashed3
36	You have been assigned a trip with bus Ba-48-5757, shift afternoon on 2024-03-03. Staffs rashed3 and azim990.	2024-03-03 12:00:22.555669+06	New Trip Allocation	azim990
37	You have been assigned a trip with bus Ba-19-0569, shift morning on 2024-03-03. Staffs altaf and jamal7898.	2024-03-03 12:00:25.157284+06	New Trip Allocation	altaf
38	You have been assigned a trip with bus Ba-19-0569, shift morning on 2024-03-03. Staffs altaf and jamal7898.	2024-03-03 12:00:25.775416+06	New Trip Allocation	jamal7898
39	You have been assigned a trip with bus Ba-19-0569, shift morning on 2024-03-03. Staffs rashed3 and jamal7898.	2024-03-03 12:00:32.343632+06	New Trip Allocation	rashed3
40	You have been assigned a trip with bus Ba-19-0569, shift morning on 2024-03-03. Staffs rashed3 and jamal7898.	2024-03-03 12:00:32.765922+06	New Trip Allocation	jamal7898
41	You have been assigned a trip with bus Ba-19-0569, shift evening on 2024-03-03. Staffs jahangir and jamal7898.	2024-03-03 12:07:54.708977+06	New Trip Allocation	jahangir
42	You have been assigned a trip with bus Ba-19-0569, shift evening on 2024-03-03. Staffs jahangir and jamal7898.	2024-03-03 12:07:55.094583+06	New Trip Allocation	jamal7898
43	You have been assigned a trip with bus Ba-24-8518, shift morning on 2024-03-03. Staffs altaf and farid99.	2024-03-03 12:13:09.872223+06	New Trip Allocation	altaf
44	You have been assigned a trip with bus Ba-24-8518, shift morning on 2024-03-03. Staffs altaf and farid99.	2024-03-03 12:13:10.279441+06	New Trip Allocation	farid99
45	notif for nfu only	2024-03-03 16:29:38.146008+06	Hi nfu 	1905077
46	notif for nfu only	2024-03-03 16:29:55.773108+06	Hi nfu 	1905077
47	notif for nfu only	2024-03-03 17:29:42.374203+06	Hi nfu 	1905077
48	notif for nfu only	2024-03-03 17:30:04.238512+06	Hi nfu 	1905077
49	You have been assigned a trip with bus Ba-77-7044, shift morning on 2024-03-03. Staffs rahmatullah and mahabhu.	2024-03-03 17:53:37.185643+06	New Trip Allocation	rahmatullah
50	You have been assigned a trip with bus Ba-77-7044, shift morning on 2024-03-03. Staffs rahmatullah and mahabhu.	2024-03-03 17:53:37.559552+06	New Trip Allocation	mahabhu
51	lol	2024-03-03 18:14:30.687016+06	test from nfu for cringe notification 	1905077
52	lol	2024-03-03 18:15:39.659134+06	test from nfu for cringe notification 	1905077
53	lol	2024-03-03 18:15:58.114668+06	test from nfu for cringe notification 	1905077
54	lol	2024-03-03 18:16:35.349563+06	test from nfu for cringe notification 	1905077
56	Reminder: You have pending tasks. Please check your dashboard.	2024-03-03 18:59:37.540813+06	New Trip Allocation	mrinmoy
57	Reminder: You have pending payment. Please check your dashboard.	2024-03-03 19:08:00.965295+06	Pending Payment	mrinmoy
58	Reminder: You have pending payment. Please check your dashboard.	2024-03-03 19:11:48.016851+06	Pending Payment	jawad
59	Reminder: You have pending payment. Please check your dashboard.	2024-03-03 19:11:48.886347+06	Pending Payment	mrinmoy
60	Reminder: You have pending payment. Please check your dashboard.	2024-03-03 19:34:26.713105+06	Pending Payment	jawad
61	Reminder: You have pending payment. Please check your dashboard.	2024-03-03 19:34:27.205939+06	Pending Payment	mrinmoy
62	lol bruh	2024-03-03 19:43:40.043204+06	bruh	1905077
63	lol bruhhhhhhhhh	2024-03-03 19:45:32.606653+06	bruhhhhhhhhh	1905077
64	lol bruhhhhhhhhh 2	2024-03-03 20:06:10.05054+06	bruhhhhhhhhh 2	1905077
65	lol bruhhhhhhhhh 2	2024-03-03 20:39:10.995908+06	bruhhhhhhhhh 2	1905067
66	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs altaf and reyazul.	2024-03-04 13:59:33.956018+06	Trip Assigned	altaf
68	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs altaf and reyazul.	2024-03-04 13:59:39.883521+06	Trip Assigned	altaf
70	You have been assigned a trip with bus Ba-19-0569, shift evening on 2024-03-04. Staffs altaf and jamal7898.	2024-03-04 14:01:46.476336+06	Trip Assigned	altaf
72	You have been assigned a trip with bus Ba-19-0569, shift evening on 2024-03-04. Staffs altaf and jamal7898.	2024-03-04 14:02:21.795906+06	Trip Assigned	altaf
74	You have been assigned a trip with bus Ba-97-6734, shift afternoon on 2024-03-04. Staffs altaf and siam34.	2024-03-04 14:03:29.925233+06	Trip Assigned	altaf
76	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs marufmorshed and reyazul.	2024-03-04 14:05:03.349475+06	Trip Assigned	marufmorshed
78	You have been assigned a trip with bus Ba-97-6734, shift afternoon on 2024-03-04. Staffs rashed3 and siam34.	2024-03-04 14:11:10.872509+06	Trip Assigned	rashed3
80	You have been assigned a trip with bus Ba-97-6734, shift afternoon on 2024-03-04. Staffs rashed3 and siam34.	2024-03-04 14:11:12.846756+06	Trip Assigned	rashed3
81	You have been assigned a trip with bus Ba-97-6734, shift afternoon on 2024-03-04. Staffs rashed3 and siam34.	2024-03-04 14:11:13.251479+06	Trip Assigned	rashed3
84	You have been assigned a trip with bus Ba-85-4722, shift evening on 2024-03-04. Staffs galloway67 and alamgir.	2024-03-04 14:14:35.301112+06	Trip Assigned	galloway67
86	You have been assigned a trip with bus Ba-85-4722, shift evening on 2024-03-04. Staffs sohel55 and alamgir.	2024-03-04 14:15:07.974981+06	Trip Assigned	sohel55
88	You have been assigned a trip with bus Ba-63-1146, shift morning on 2024-03-04. Staffs arif43 and zahir53.	2024-03-04 14:15:43.297079+06	Trip Assigned	arif43
90	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs marufmorshed and mahmud64.	2024-03-04 14:16:30.494895+06	Trip Assigned	marufmorshed
92	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and mahmud64.	2024-03-04 14:18:15.136574+06	Trip Assigned	ibrahim
94	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and siam34.	2024-03-04 14:19:22.689985+06	Trip Assigned	ibrahim
96	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and siam34.	2024-03-04 14:19:28.66561+06	Trip Assigned	ibrahim
97	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and siam34.	2024-03-04 14:19:28.991913+06	Trip Assigned	ibrahim
99	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and siam34.	2024-03-04 14:19:29.321666+06	Trip Assigned	ibrahim
100	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and siam34.	2024-03-04 14:19:29.359766+06	Trip Assigned	ibrahim
102	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and siam34.	2024-03-04 14:19:29.910061+06	Trip Assigned	ibrahim
105	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and siam34.	2024-03-04 14:19:30.809321+06	Trip Assigned	ibrahim
106	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and siam34.	2024-03-04 14:19:31.375583+06	Trip Assigned	ibrahim
107	You have been assigned a trip with bus Ba-63-1146, shift morning on 2024-03-04. Staffs altaf and zahir53.	2024-03-04 14:21:57.963864+06	Trip Assigned	altaf
109	You have been assigned a trip with bus Ba-86-1841, shift evening on 2024-03-04. Staffs shahid88 and shamsul54.	2024-03-04 14:24:36.173744+06	Trip Assigned	shahid88
111	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and nasir81.	2024-03-04 14:25:26.28217+06	Trip Assigned	ibrahim
113	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and siam34.	2024-03-04 14:26:20.956213+06	Trip Assigned	ibrahim
115	You have been assigned a trip with bus Ba-46-1334, shift morning on 2024-03-04. Staffs ibrahim and shamsul54.	2024-03-04 14:26:59.83596+06	Trip Assigned	ibrahim
117	You have been assigned a trip with bus Ba-77-7044, shift evening on 2024-03-04. Staffs arif43 and ghioe22.	2024-03-04 15:08:14.662904+06	Trip Assigned	arif43
119	You have been assigned a trip with bus Ba-77-7044, shift evening on 2024-03-04. Staffs altaf and ghioe22.	2024-03-04 15:08:21.501638+06	Trip Assigned	altaf
121	You have been assigned a trip with bus Ba-77-7044, shift evening on 2024-03-04. Staffs fazlu77 and ghioe22.	2024-03-04 15:08:50.270471+06	Trip Assigned	fazlu77
123	You have been assigned a trip with bus Ba-77-7044, shift evening on 2024-03-04. Staffs altaf and ghioe22.	2024-03-04 15:09:02.665014+06	Trip Assigned	altaf
125	You have been assigned a trip with bus Ba-35-1461, shift morning on 2024-03-04. Staffs altaf and mahmud64.	2024-03-04 15:10:39.543738+06	Trip Assigned	altaf
127	You have been assigned a trip with bus Ba-35-1461, shift morning on 2024-03-04. Staffs rashed3 and mahmud64.	2024-03-04 15:11:06.076359+06	Trip Assigned	rashed3
129	You have been assigned a trip with bus Ba-93-6087, shift evening on 2024-03-04. Staffs altaf and izdn56.	2024-03-04 15:11:41.405585+06	Trip Assigned	altaf
131	You have been assigned a trip with bus Ba-86-1841, shift evening on 2024-03-04. Staffs altaf and shamsul54.	2024-03-04 15:36:14.112411+06	Trip Assigned	altaf
133	Reminder: You have pending payment. Please check your dashboard.	2024-03-04 15:38:48.243229+06	Pending Payment	mrinmoy
134	Reminder: You have pending payment. Please check your dashboard.	2024-03-04 15:38:49.597813+06	Pending Payment	mrinmoy
135	ৱাছিফ জলালৰ দৰে এটা পাৰছ'নেল ন'টিফিকে'ছ'ন 	2024-04-22 15:35:53.049929+06	Hi glob 	1905084
136	You have been assigned a trip with bus Ba-46-1334, shift evening on 2024-04-22. Staffs altaf78 and reyazul.	2024-04-22 22:54:38.802357+06	Trip Assigned	altaf78
138	You have been assigned a trip with bus Ba-34-7413, shift evening on 2024-04-23. Staffs altaf78 and nasir81.	2024-04-23 16:20:19.313493+06	Trip Assigned	altaf78
140	You have been assigned a trip with bus Ba-36-1921, shift afternoon on 2024-04-23. Staffs imranhashmi and ASADUZZAMAN.	2024-04-23 16:21:24.691364+06	Trip Assigned	imranhashmi
142	Reminder: You have pending payment. Please check your dashboard.	2024-04-23 16:32:00.619209+06	Pending Payment	mashiat
143	Reminder: You have pending payment. Please check your dashboard.	2024-04-23 16:32:01.842542+06	Pending Payment	pranto
144	Reminder: You have pending payment. Please check your dashboard.	2024-04-23 16:32:02.161272+06	Pending Payment	mashiat
145	Reminder: You have pending payment. Please check your dashboard.	2024-04-23 16:32:02.469577+06	Pending Payment	rayhan
146	Reminder: You have pending payment. Please check your dashboard.	2024-04-23 16:32:02.802313+06	Pending Payment	fahim
147	Reminder: You have pending payment. Please check your dashboard.	2024-04-23 16:32:03.110623+06	Pending Payment	jawad
148	Reminder: You have pending payment. Please check your dashboard.	2024-04-23 16:32:03.429335+06	Pending Payment	younus
149	Reminder: You have pending payment. Please check your dashboard.	2024-04-23 16:32:03.742181+06	Pending Payment	mrinmoy
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
70	1905069	2024-02-11 23:09:00.445964+06	shurjopay	65c8ff2b	50
71	1905088	2024-02-12 02:17:27.310446+06	shurjopay	65c92b56	15
72	1905077	2024-03-03 16:58:43.655345+06	shurjopay	65e457e2	50
73	1905067	2024-03-04 14:01:51.513974+06	shurjopay	65e57fee	50
74	1905088	2024-03-04 14:05:33.395151+06	shurjopay	65e580cc	50
75	1905088	2024-03-04 14:06:15.210398+06	shurjopay	65e580f6	50
76	1905077	2024-03-04 15:06:13.991265+06	shurjopay	65e58f04	50
77	1905088	2024-03-05 22:00:44.436003+06	shurjopay	65e741ab	50
78	1905067	2024-04-22 22:29:29.343487+06	shurjopay	66269068	50
79	1905088	2024-04-22 22:41:39.69402+06	shurjopay	66269342	50
80	1905088	2024-04-23 00:48:21.088856+06	shurjopay	6626b0f4	50
81	1905008	2024-04-23 01:37:02.670385+06	shurjopay	6626bc5d	100
82	1905008	2024-04-23 01:37:31.63793+06	shurjopay	6626bc7a	50
83	1905077	2024-04-23 13:37:18.973059+06	shurjopay	6627652d	50
84	1905058	2024-04-23 13:45:42.328481+06	shurjopay	66276725	50
85	1905058	2024-04-23 14:20:48.182005+06	shurjopay	66276f5f	200
86	1905058	2024-04-23 15:29:18.616128+06	shurjopay	66277f6c	50
\.


--
-- Data for Name: repair; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.repair (id, requestor, bus, parts, request_des, repair_des, "timestamp", is_repaired, missing) FROM stdin;
1	altaf	Ba-46-1334	Shock absorber, right side mirror	The mirror is broken and the shock absrober is not working	Please install a more durable mirror. The shock absorber is damaged on its right side	2024-03-03 21:19:44.903189+06	t	\N
4	rahmatullah	Ba-20-3066	socket zampar	it is not work saar pls update 		2024-03-04 10:37:10.860022+06	f	\N
5	altaf	Ba-86-1841	Headlights	need lights	need repair	2024-03-04 11:48:33.118159+06	f	\N
6	ibrahim	BA-01-2345	engine	bad noises	pls repair it 	2024-03-04 15:10:30.386025+06	f	\N
2	altaf	Ba-86-1841	Wheel	Need a new wheel	Headlight needs to be fixed	2024-03-03 21:51:34.226471+06	t	\N
7	nizam88	Ba-24-8518	spare tire	pls send mire tires 		2024-04-23 15:40:46.322869+06	f	\N
3	altaf	Ba-46-1334	Looking glass 	Current looking glass is broken.		2024-03-03 22:37:08.204786+06	t	\N
\.


--
-- Data for Name: requisition; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.requisition (id, requestor_id, source, destination, subject, text, "timestamp", approved_by, bus_type, valid, allocation_id, remarks, is_approved) FROM stdin;
46	pranto	BUET Cafeteria	Cox's Bazar	official	We need a bus for Nsys3 conference.	2024-05-09 07:30:00+06	reyazul	{normal}	t	\N		t
47	pranto	ECE Building	Narayanganj	official	Needed for programming contest	2024-04-30 07:30:00+06	reyazul	{mini}	t	\N		t
39	sayem	cantonment	adabor	official	checking if it works	2024-04-18 09:22:00+06	mashroor	{mini}	t	\N	hello, retry	t
40	mrinmoy	Buet	Sylhet	personal	jabo yay	2024-03-05 08:30:00+06	reyazul	{mini}	t	\N		t
45	pranto	ECE Building	Narayanganj	BRTC	For CTF contest	2024-04-30 09:30:00+06	\N	{mini}	t	\N	\N	\N
42	rayhan	BUET	IDB	official	Computer 	2024-03-06 08:30:00+06	reyazul	{car}	t	\N	bhalo lage nai idea	f
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

COPY public.schedule (id, start_timestamp, route, time_type, time_list, travel_direction, default_driver, default_helper, default_bus) FROM stdin;
15	2023-08-25 23:30:00+06	6	evening	{"(41,\\"2023-08-25 23:30:00+06\\")","(42,\\"2023-08-25 23:46:00+06\\")","(43,\\"2023-08-25 23:48:00+06\\")","(44,\\"2023-08-25 23:50:00+06\\")","(45,\\"2023-08-25 23:52:00+06\\")","(46,\\"2023-08-25 23:54:00+06\\")","(47,\\"2023-08-25 23:56:00+06\\")","(48,\\"2023-08-25 23:58:00+06\\")","(49,\\"2023-08-26 00:00:00+06\\")","(70,\\"2023-08-26 00:02:00+06\\")"}	from_buet	altaf78	mahabhu	Ba-83-8014
13	2023-08-25 12:40:00+06	6	morning	{"(41,\\"2023-08-25 12:40:00+06\\")","(42,\\"2023-08-25 12:42:00+06\\")","(43,\\"2023-08-25 12:45:00+06\\")","(44,\\"2023-08-25 12:47:00+06\\")","(45,\\"2023-08-25 12:49:00+06\\")","(46,\\"2023-08-25 12:51:00+06\\")","(47,\\"2023-08-25 12:52:00+06\\")","(48,\\"2023-08-25 12:53:00+06\\")","(49,\\"2023-08-25 12:54:00+06\\")","(70,\\"2023-08-25 13:10:00+06\\")"}	to_buet	shahid88	azim990	Ba-97-6734
14	2023-08-25 19:40:00+06	6	afternoon	{"(41,\\"2023-08-25 19:40:00+06\\")","(42,\\"2023-08-25 19:56:00+06\\")","(43,\\"2023-08-25 19:58:00+06\\")","(44,\\"2023-08-25 20:00:00+06\\")","(45,\\"2023-08-25 20:02:00+06\\")","(46,\\"2023-08-25 20:04:00+06\\")","(47,\\"2023-08-25 20:06:00+06\\")","(48,\\"2023-08-25 20:08:00+06\\")","(49,\\"2023-08-25 20:10:00+06\\")","(70,\\"2023-08-25 20:12:00+06\\")"}	from_buet	imranhashmi	siam34	Ba-36-1921
16	2023-08-25 12:40:00+06	7	morning	{"(50,\\"2023-08-25 12:40:00+06\\")","(51,\\"2023-08-25 12:42:00+06\\")","(52,\\"2023-08-25 12:43:00+06\\")","(53,\\"2023-08-25 12:46:00+06\\")","(54,\\"2023-08-25 12:47:00+06\\")","(55,\\"2023-08-25 12:48:00+06\\")","(56,\\"2023-08-25 12:50:00+06\\")","(57,\\"2023-08-25 12:52:00+06\\")","(58,\\"2023-08-25 12:53:00+06\\")","(59,\\"2023-08-25 12:54:00+06\\")","(60,\\"2023-08-25 12:56:00+06\\")","(61,\\"2023-08-25 12:58:00+06\\")","(62,\\"2023-08-25 13:00:00+06\\")","(63,\\"2023-08-25 13:02:00+06\\")","(70,\\"2023-08-25 13:00:00+06\\")"}	to_buet	nobiulnode	mahmud64	Ba-43-4286
17	2023-08-25 19:40:00+06	7	afternoon	{"(50,\\"2023-08-25 19:40:00+06\\")","(51,\\"2023-08-25 19:48:00+06\\")","(52,\\"2023-08-25 19:50:00+06\\")","(53,\\"2023-08-25 19:52:00+06\\")","(54,\\"2023-08-25 19:54:00+06\\")","(55,\\"2023-08-25 19:56:00+06\\")","(56,\\"2023-08-25 19:58:00+06\\")","(57,\\"2023-08-25 20:00:00+06\\")","(58,\\"2023-08-25 20:02:00+06\\")","(59,\\"2023-08-25 20:04:00+06\\")","(60,\\"2023-08-25 20:06:00+06\\")","(61,\\"2023-08-25 20:08:00+06\\")","(62,\\"2023-08-25 20:10:00+06\\")","(63,\\"2023-08-25 20:12:00+06\\")","(70,\\"2023-08-25 20:14:00+06\\")"}	from_buet	polash	zahir53	Ba-35-1461
19	2023-08-25 12:15:00+06	1	morning	{"(1,\\"2023-08-25 12:15:00+06\\")","(2,\\"2023-08-25 12:18:00+06\\")","(3,\\"2023-08-25 12:20:00+06\\")","(4,\\"2023-08-25 12:23:00+06\\")","(5,\\"2023-08-25 12:26:00+06\\")","(6,\\"2023-08-25 12:29:00+06\\")","(7,\\"2023-08-25 12:49:00+06\\")","(8,\\"2023-08-25 12:51:00+06\\")","(9,\\"2023-08-25 12:53:00+06\\")","(10,\\"2023-08-25 12:55:00+06\\")","(11,\\"2023-08-25 12:58:00+06\\")","(70,\\"2023-08-25 13:05:00+06\\")"}	to_buet	monu67	farid99	Ba-85-4722
20	2023-08-25 19:40:00+06	1	afternoon	{"(1,\\"2023-08-25 19:40:00+06\\")","(2,\\"2023-08-25 19:47:00+06\\")","(3,\\"2023-08-25 19:50:00+06\\")","(4,\\"2023-08-25 19:52:00+06\\")","(5,\\"2023-08-25 19:54:00+06\\")","(6,\\"2023-08-25 20:06:00+06\\")","(7,\\"2023-08-25 20:09:00+06\\")","(8,\\"2023-08-25 20:12:00+06\\")","(9,\\"2023-08-25 20:15:00+06\\")","(10,\\"2023-08-25 20:18:00+06\\")","(11,\\"2023-08-25 20:21:00+06\\")","(70,\\"2023-08-25 20:24:00+06\\")"}	from_buet	nazrul6	kk47	Ba-93-6087
18	2023-08-25 23:30:00+06	7	evening	{"(50,\\"2023-08-25 23:30:00+06\\")","(51,\\"2023-08-25 23:38:00+06\\")","(52,\\"2023-08-25 23:40:00+06\\")","(53,\\"2023-08-25 23:42:00+06\\")","(54,\\"2023-08-25 23:44:00+06\\")","(55,\\"2023-08-25 23:46:00+06\\")","(56,\\"2023-08-25 23:48:00+06\\")","(57,\\"2023-08-25 23:50:00+06\\")","(58,\\"2023-08-25 23:52:00+06\\")","(59,\\"2023-08-25 23:54:00+06\\")","(60,\\"2023-08-25 23:56:00+06\\")","(61,\\"2023-08-25 23:58:00+06\\")","(62,\\"2023-08-26 00:00:00+06\\")","(63,\\"2023-08-26 00:02:00+06\\")","(70,\\"2023-08-26 00:04:00+06\\")"}	from_buet	masud84	reyazul	Ba-46-1334
4	2023-08-25 12:40:00+06	3	morning	{"(17,\\"2023-08-25 12:40:00+06\\")","(18,\\"2023-08-25 12:42:00+06\\")","(19,\\"2023-08-25 12:44:00+06\\")","(20,\\"2023-08-25 12:46:00+06\\")","(21,\\"2023-08-25 12:48:00+06\\")","(22,\\"2023-08-25 12:50:00+06\\")","(23,\\"2023-08-25 12:52:00+06\\")","(24,\\"2023-08-25 12:54:00+06\\")","(25,\\"2023-08-25 12:57:00+06\\")","(26,\\"2023-08-25 13:00:00+06\\")","(70,\\"2023-08-25 13:15:00+06\\")"}	to_buet	rashed3	abdulbari4	Ba-17-3886
5	2023-08-25 19:40:00+06	3	afternoon	{"(17,\\"2023-08-25 19:40:00+06\\")","(18,\\"2023-08-25 19:55:00+06\\")","(19,\\"2023-08-25 19:58:00+06\\")","(20,\\"2023-08-25 20:00:00+06\\")","(21,\\"2023-08-25 20:02:00+06\\")","(22,\\"2023-08-25 20:04:00+06\\")","(23,\\"2023-08-25 20:06:00+06\\")","(24,\\"2023-08-25 20:08:00+06\\")","(25,\\"2023-08-25 20:10:00+06\\")","(26,\\"2023-08-25 20:12:00+06\\")","(70,\\"2023-08-25 20:14:00+06\\")"}	from_buet	felicitades35	rishisunak45	Ba-12-8888
7	2023-08-25 12:40:00+06	4	morning	{"(27,\\"2023-08-25 12:40:00+06\\")","(28,\\"2023-08-25 12:42:00+06\\")","(29,\\"2023-08-25 12:44:00+06\\")","(30,\\"2023-08-25 12:46:00+06\\")","(31,\\"2023-08-25 12:50:00+06\\")","(32,\\"2023-08-25 12:52:00+06\\")","(33,\\"2023-08-25 12:54:00+06\\")","(34,\\"2023-08-25 12:58:00+06\\")","(35,\\"2023-08-25 13:00:00+06\\")","(70,\\"2023-08-25 13:10:00+06\\")"}	to_buet	galloway67	dariengap30	Ba-69-8288
24	2023-08-25 23:30:00+06	8	evening	{"(64,\\"2023-08-25 23:30:00+06\\")","(65,\\"2023-08-25 23:45:00+06\\")","(66,\\"2023-08-25 23:48:00+06\\")","(67,\\"2023-08-25 23:51:00+06\\")","(68,\\"2023-08-25 23:54:00+06\\")","(69,\\"2023-08-25 23:57:00+06\\")","(70,\\"2023-08-26 00:00:00+06\\")"}	from_buet	marufmorshed	jamal7898	Ba-19-0569
1	2023-08-25 12:55:00+06	2	morning	{"(12,\\"2023-08-25 12:55:00+06\\")","(13,\\"2023-08-25 12:57:00+06\\")","(14,\\"2023-08-25 12:59:00+06\\")","(15,\\"2023-08-25 13:01:00+06\\")","(16,\\"2023-08-25 13:03:00+06\\")","(70,\\"2023-08-25 13:15:00+06\\")"}	to_buet	aminhaque	refugee23	Ba-22-4326
2	2023-08-25 19:40:00+06	2	afternoon	{"(12,\\"2023-08-25 19:40:00+06\\")","(13,\\"2023-08-25 19:52:00+06\\")","(14,\\"2023-08-25 19:54:00+06\\")","(15,\\"2023-08-25 19:57:00+06\\")","(16,\\"2023-08-25 20:00:00+06\\")","(70,\\"2023-08-25 20:03:00+06\\")"}	from_buet	kamaluddin	rgbmbrt	Ba-69-8288
3	2023-08-25 23:30:00+06	2	evening	{"(12,\\"2023-08-25 23:30:00+06\\")","(13,\\"2023-08-25 23:42:00+06\\")","(14,\\"2023-08-25 23:45:00+06\\")","(15,\\"2023-08-25 23:48:00+06\\")","(16,\\"2023-08-25 23:51:00+06\\")","(70,\\"2023-08-25 23:54:00+06\\")"}	from_buet	altaf	shamsul54	Ba-86-1841
9	2023-08-25 23:30:00+06	4	evening	{"(27,\\"2023-08-25 23:30:00+06\\")","(28,\\"2023-08-25 23:40:00+06\\")","(29,\\"2023-08-25 23:42:00+06\\")","(30,\\"2023-08-25 23:44:00+06\\")","(31,\\"2023-08-25 23:46:00+06\\")","(32,\\"2023-08-25 23:48:00+06\\")","(33,\\"2023-08-25 23:50:00+06\\")","(34,\\"2023-08-25 23:52:00+06\\")","(35,\\"2023-08-25 23:54:00+06\\")","(70,\\"2023-08-25 23:56:00+06\\")"}	from_buet	sohel55	germs23	Ba-98-5568
10	2023-08-25 12:30:00+06	5	morning	{"(36,\\"2023-08-25 12:30:00+06\\")","(37,\\"2023-08-25 12:33:00+06\\")","(38,\\"2023-08-25 12:40:00+06\\")","(39,\\"2023-08-25 12:45:00+06\\")","(40,\\"2023-08-25 12:50:00+06\\")","(70,\\"2023-08-25 13:00:00+06\\")"}	to_buet	nizam88	rashid56	Ba-24-8518
12	2023-08-25 23:30:00+06	5	evening	{"(36,\\"2023-08-25 23:30:00+06\\")","(37,\\"2023-08-25 23:40:00+06\\")","(38,\\"2023-08-25 23:45:00+06\\")","(39,\\"2023-08-25 23:50:00+06\\")","(40,\\"2023-08-25 23:57:00+06\\")","(70,\\"2023-08-26 00:00:00+06\\")"}	from_buet	galloway67	ghioe22	Ba-77-7044
11	2023-08-25 19:40:00+06	5	afternoon	{"(36,\\"2023-08-25 19:40:00+06\\")","(37,\\"2023-08-25 19:50:00+06\\")","(38,\\"2023-08-25 19:55:00+06\\")","(39,\\"2023-08-25 20:00:00+06\\")","(40,\\"2023-08-25 20:07:00+06\\")","(70,\\"2023-08-25 20:10:00+06\\")"}	from_buet	rahmatullah	mahbub777	Ba-20-3066
21	2023-08-25 23:30:00+06	1	evening	{"(1,\\"2023-08-25 23:30:00+06\\")","(2,\\"2023-08-25 23:37:00+06\\")","(3,\\"2023-08-25 23:40:00+06\\")","(4,\\"2023-08-25 23:42:00+06\\")","(5,\\"2023-08-25 23:44:00+06\\")","(6,\\"2023-08-25 23:56:00+06\\")","(7,\\"2023-08-25 23:59:00+06\\")","(8,\\"2023-08-26 00:02:00+06\\")","(9,\\"2023-08-26 00:05:00+06\\")","(10,\\"2023-08-26 00:08:00+06\\")","(11,\\"2023-08-26 00:11:00+06\\")","(70,\\"2023-08-26 00:14:00+06\\")"}	from_buet	abdulkarim6	siddiq2	Ba-48-5757
22	2023-08-25 12:10:00+06	8	morning	{"(64,\\"2023-08-25 12:10:00+06\\")","(65,\\"2023-08-25 12:13:00+06\\")","(66,\\"2023-08-25 12:18:00+06\\")","(67,\\"2023-08-25 12:20:00+06\\")","(68,\\"2023-08-25 12:22:00+06\\")","(69,\\"2023-08-25 12:25:00+06\\")","(70,\\"2023-08-25 12:40:00+06\\")"}	to_buet	shafiqul	sharif86r	Ba-17-2081
23	2023-08-25 19:40:00+06	8	afternoon	{"(64,\\"2023-08-25 19:40:00+06\\")","(65,\\"2023-08-25 19:55:00+06\\")","(66,\\"2023-08-25 19:58:00+06\\")","(67,\\"2023-08-25 20:01:00+06\\")","(68,\\"2023-08-25 20:04:00+06\\")","(69,\\"2023-08-25 20:07:00+06\\")","(70,\\"2023-08-25 20:10:00+06\\")"}	from_buet	jahangir	khairul	Ba-71-7930
6	2023-08-25 23:30:00+06	3	evening	{"(17,\\"2023-08-25 23:30:00+06\\")","(18,\\"2023-08-25 23:45:00+06\\")","(19,\\"2023-08-25 23:48:00+06\\")","(20,\\"2023-08-25 23:50:00+06\\")","(21,\\"2023-08-25 23:52:00+06\\")","(22,\\"2023-08-25 23:54:00+06\\")","(23,\\"2023-08-25 23:56:00+06\\")","(24,\\"2023-08-25 23:58:00+06\\")","(25,\\"2023-08-26 00:00:00+06\\")","(26,\\"2023-08-26 00:02:00+06\\")","(70,\\"2023-08-26 00:04:00+06\\")"}	from_buet	fazlu77	nasir81	Ba-34-7413
8	2023-08-25 19:40:00+06	4	afternoon	{"(27,\\"2023-08-25 19:40:00+06\\")","(28,\\"2023-08-25 19:50:00+06\\")","(29,\\"2023-08-25 19:52:00+06\\")","(30,\\"2023-08-25 19:54:00+06\\")","(31,\\"2023-08-25 19:56:00+06\\")","(32,\\"2023-08-25 19:58:00+06\\")","(33,\\"2023-08-25 20:00:00+06\\")","(34,\\"2023-08-25 20:02:00+06\\")","(35,\\"2023-08-25 20:04:00+06\\")","(70,\\"2023-08-25 20:06:00+06\\")"}	from_buet	ibrahim	greece01	BA-01-2345
\.


--
-- Data for Name: session; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session (sid, sess, expire) FROM stdin;
Wm3AiN4QVeszvb3Zp2vL0dlpL_EGFhsm	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-05-24T09:13:06.691Z","httpOnly":false,"path":"/"},"userid":"1905058","user_type":"student","fcm_id":"eyNAUiilSH-Yu7EBGX3Nef:APA91bGI5MuT476GPsa4pZRON7VhNdJX5uSyRMEywm_wdc6cCaFEg9-yrgtnPoJbRr7tgIldvgR1DFNUKKcmCn-7o2Hlt8tQ9YW87Ud6tKcF0ApGgY02umdRuLBLeYEDogc-UPhVjzZt"}	2024-05-24 15:17:21
aLYZT5BrLuBs7XzVkNXjJ-9ThKdCdkwn	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-05-22T18:56:36.198Z","httpOnly":false,"path":"/"},"userid":"pranto","user_type":"buet_staff","fcm_id":"cJ3m345vTLe_vYrilyh2l0:APA91bHjmlGbTxrb-Nk1O3GKBjUVrxpaI_SHD4uYitB-tNNiU0Xtsu0xenCa6kbIBXAmb82VTjL4FsYl06At-Z06MSaTooHZg4XBKWYxxiV4V2mhZjc31beRmavUr0mOwWe5ujFfQBr-"}	2024-05-23 01:02:31
xkzcFA2cZF4hT0yMT_IRFpFIghKxZHHp	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-05-22T17:54:05.196Z","httpOnly":false,"path":"/"},"userid":"1905084","user_type":"student","fcm_id":"fOeFHWq5RZ-c7jFZSd_hn1:APA91bFY8A6h2IX1drbF2d4Y1P5-RcwI9W9OQ_KjwjN-QYpp1ngaq_BZU9o-e1aZaX_H_BgBQljQKh3x0PaRDqVfnFs2Z2_FhTj0JR-nP08Ps1qOridAQ4__n80lcOXbidzofVO0q23S"}	2024-05-22 23:54:15
3Ge9k1T9jtnc4ulBez0ava9uqDI_vC9e	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-05-26T19:17:47.704Z","httpOnly":false,"path":"/"},"userid":"1905077","user_type":"student","fcm_id":"dhgQcfgLRTGUVMIuayuVsT:APA91bGcjqwj9V391STjKkEBO0n3eVyLhVWgX6CMiLDLBd8XukTGYqmDxkAH7yb9JQfgsaVe5Ij09h9nHMT3zulDcBe7ZCZOs3o3HpdhL110afjH173tRokDv9kRfoVr_2RIuyiHJGP3"}	2024-05-28 12:27:57
T2njF805NkSOOSUSl46pAU93OtwnJ7CL	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-05-24T09:12:26.760Z","httpOnly":false,"path":"/"},"userid":"1905058","user_type":"student","fcm_id":"fZftsW7rRV-D3_LET62Ut4:APA91bEYf4mTaJm2LeRyulqWDd8fKueqVjO0T6O9jzb1NBV0dX-4fP7vANWNd-CNrfe4DiIEh2zgeve89lg2aXo9s73jJ8bemhJBnztBSbdoMKlqX8rq00IXUdKZc0n9v7nnRYlLvJeO"}	2024-05-24 15:12:35
C7Yay50NEj-4xrbEYI8P7PBgyg2kheuf	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-05-23T07:03:32.045Z","httpOnly":false,"path":"/"},"userid":"1905058","user_type":"student","fcm_id":"dnr1kpZfRDCRdSoPRZ72xB:APA91bFlUPcminLzrqBEta24p0qgF_OSqLBxBfV2p8Sc756iSc8xq37aFOn6rX2qwxwdy3dghqV4jns2ORDyGLVkuixawmzGfy6PejLm3vDISzrThUyE0634ldZadx9I_-MohaVRyn9P"}	2024-05-26 20:03:11
Cv7pFt0PXc6ekLJjdaeOD7-PSjfgjmiM	{"cookie":{"originalMaxAge":2592000000,"expires":"2024-05-27T20:47:12.580Z","httpOnly":false,"path":"/"},"userid":"1905084","user_type":"student","fcm_id":"d1PCKH29RjeQgJdBe5msB7:APA91bHBWxTtcCK048MmE7SMmqC9PPpqyaJiI2xbx4lEp-neE-KtXp1pFgB3AgY6J66fV0fzGqfOB9ZduLfcIRf3c7nlg4D2UTiFsNvKmqdFyO8OamhMPK27mBPECl-6Ef96iTDD0cHH"}	2024-05-28 13:30:00
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
1905081	01312453445	1905081@cse.buet.ac.bd	$2b$10$MU4PaW4ooqEIyTaqYxlJiOCtpb7Ay38Sdc/ISINvlCaq7piDw//gS	5	Ahmed Farhan Shahriar Chowdhury	36	t
1905001	01695678951	sadathossain@gmail.com	$2a$12$tOnTnGZJpqDBb/bqO2KSYe7DgNYz42AEZ7bQv5Tjna5vCIV530MX.	3	Sadat Hossain	17	t
1905008	01742378641	1905008@ugrad.cse.ac.bd	$2b$10$EpGSywNYw/fPGt.Iq2QyXeE1GOlkxPRg0.9zXl2eYBJgjGjGxoHpa	5	Shattik Islam	37	t
1905058	01521564856	ahmedsadif67@gmail.com	$2a$12$tXuYcuW712UpgJiFY.Rj5euinUdAPVIfIfpUnyeDDh0rZmPby6/Vu	5	Sadif Ahmed	36	t
1905105	01976837633	shahriarraj121@gmail.com	$2a$12$dCICg8hcWHYCvnF.RNKDi.8oM3vGUZEDXYS2pNL4nMIM8Gn4h2V4e	5	Shahriar Raj	36	t
69     	01234567890	nafiu.grahman@gmail.com	$2a$12$4pDhPGmCJDOonyuCQMAQIudSQn8CFXvZY3xDaHemv9REetifbVSKe	5	Based Rahman	38	t
78     	01311111111	maliha@gmail.com	$2b$10$nWYI9PFppt.K29rUp0goJOuOxw2ciE2/l8afuG/6bNsYVbfSF5YMW	7	Maliha	33	t
82     	01521564738	kazireyazulhasan@gmail.com	$2b$10$TphyE44V6H683vNhMFY9x.6tb1aj1x5omFa7CtE2J/86BP3jnTA4S	5	Kazi Reyazul Hasan	14	t
88     	01521564738	kazireyazulhasan@gmail.com	$2b$10$DmxlF076lspjifV0Gdh.ue3O.h7YyegFTOVXx2vuFIQ3Djfng8SOG	2	Musarrat	6	t
1905069	01234567894	mhb69@gmail.com	$2a$12$uFsNORh9NT51ORsUacMDi.G7XfzrmTbSTcsDPRJvdIhEN2kBqIdmO	1	Mashroor Hasan Bhuiyan	7	t
1905082	01521564748	kz.rxl.hsn@gmail.com	$2a$12$PJ1xmj9l2Ab6AT8pnvuzEe06fum1yCkUD5gv.2M0ehBbmhmR0GuY6	7	Kazi Reyazul Hasan	12	t
87     	01513111111	asad@gmail.com	$2b$10$tW/qPpOLrWoi2OsojtyZ2uzMZb/r5AX303BGNqAMDfK3pwrbzrOCu	8	Asad	7	t
1905077	01284852645	nafiu.rahhman@gmail.com	$2a$12$2rrw/Jyeq/XSu/jLXlibmu.XqaYBYeb2YooQW2CBxNKSUKj5cSv2a	5	Nafiu Rahman	37	t
1905084	01729733687	jalalwasif@gmail.com	$2a$12$MvqL5LGR/K1VVJpev3wxoO/XKoS/EP.D/Zch1p8eAmOKcQ.WZIg7u	5	Wasif Jalal	37	t
1905067	01878117219	sojibxaman439@gmail.com	$2a$12$sLZ8yzBa7fo3heCPgdni8Oc9Iv3.hIwaZjcx8cV6y8Rn4pA04jU8.	4	MD. ROQUNUZZAMAN SOJIB	27	t
1906192	01555555555	mashroor184@gmail.com	$2b$10$9PH0VNS3NkTVDQCDnJIXVeZCmAW.J2DWE4NRM9GGQ65KPzXzIKXyG	5	Akif Hamid	41	t
1905088	01828282828	mubasshira728@gmail.com	$2a$12$2ptBYlOMiHNhpFPEDt2gOeclWgc6ZhAKlzN7YskA0Do5NeXZZo5di	6	Mubasshira Musarrat	47	t
\.


--
-- Data for Name: student_feedback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_feedback (id, complainer_id, route, submission_timestamp, concerned_timestamp, text, trip_id, subject, response, valid) FROM stdin;
8	69	3	2023-09-06 21:01:31.633662+06	2023-09-01 06:00:00+06	The time table should be changed. So unnecessary to start journey at 6:15AM in the morning. 	\N	{bus}	Thank you for your request. It has automatically been ignored.	t
12	1905084	3	2023-09-07 04:38:22.389025+06	\N	seat bhanga	\N	{bus}	\N	t
16	1905067	6	2023-09-07 11:12:52.902353+06	\N	Bus didn't reach buet in time. Missed ct	\N	{bus}	\N	t
17	1905067	4	2023-09-07 11:13:30.087775+06	2023-08-24 00:00:00+06	Staff was very rude	\N	{staff}	\N	t
18	1905067	3	2023-09-07 11:14:10.821911+06	2023-09-04 00:00:00+06	Driver came late	\N	{driver}	\N	t
20	1905067	7	2023-09-07 11:18:51.84041+06	\N	Can install some fans	\N	{other}	\N	t
21	1905088	5	2023-09-07 11:25:20.058267+06	2023-09-05 00:00:00+06	Helper was very rude. shouted on me	\N	{staff}	\N	t
22	1905088	6	2023-09-07 11:26:39.318946+06	2023-09-06 00:00:00+06	Bus left the station earlier than the given time in the morning without any prior notice	\N	{bus}	\N	t
23	1905088	1	2023-09-07 11:27:26.44088+06	2023-08-16 00:00:00+06	Too crowded. Should assign another bus in this route	\N	{other}	\N	t
25	1905077	5	2023-09-07 11:43:47.455913+06	2023-09-05 00:00:00+06	bad seating service	\N	{staff}	\N	t
15	1905067	5	2023-09-07 11:12:05.993256+06	2023-08-08 00:00:00+06	way too many passengers	\N	{other}	Sorry but we are trying to expand capacity	t
19	1905067	2	2023-09-07 11:14:55.781888+06	\N	Bus left the station before time in the morning	\N	{bus}	According to our data the bus left in correct time, if you would like to take you claim further then pls contact the authority with definitive evidence	t
26	1905077	6	2023-09-07 11:44:13.981407+06	2023-09-02 00:00:00+06	no fan in bus	\N	{driver}	we are planning to install new fans next semester, pls be patient till then.	t
27	1905077	5	2023-09-07 12:00:58.617135+06	2023-09-05 00:00:00+06	rough driving	\N	{staff}	\N	t
28	1905088	5	2023-09-07 14:39:49.325426+06	2023-09-06 00:00:00+06	rude driver	\N	{driver}	\N	t
31	1905084	5	2023-09-08 00:42:30.790952+06	2023-09-07 00:00:00+06	Did not stop when I asked to	\N	{driver}	\N	t
34	1905077	1	2023-09-15 11:46:26.199246+06	2023-09-05 00:00:00+06	Dangerous driving 	\N	{staff}	\N	t
35	1905077	1	2023-09-15 11:46:46.502356+06	2023-09-05 00:00:00+06	Dangerous driving 	\N	{staff}	\N	t
36	1905067	1	2024-01-04 20:15:34.335892+06	2023-10-05 11:48:00+06	The driver was driving without any caution. He almost hit a bike on the road. 	\N	{driver}	\N	t
37	1905067	1	2024-01-04 20:16:01.78843+06	2023-10-05 11:48:00+06	The driver was driving without any caution. He almost hit a bike on the road. 	\N	{driver}	\N	t
38	1905067	1	2024-01-06 12:38:25.721532+06	2023-10-05 11:48:00+06	The driver was so bad.	\N	{driver}	\N	t
39	1905067	1	2024-01-06 13:14:21.261369+06	2023-10-05 11:48:00+06	bad driver	\N	{driver}	\N	t
50	1905105	5	2024-02-06 12:33:29.114251+06	2024-01-20 00:00:00+06	The bus was late. 	\N	{driver,bus}	\N	t
51	1905105	5	2024-02-06 12:35:44.256871+06	2024-01-27 00:00:00+06	The bus left without me 	\N	{driver,bus,staff}	\N	t
47	69	2	2024-01-29 09:42:23.279531+06	2024-01-23 00:00:00+06	Jhamela hoise	\N	{driver}	ok	t
55	1905088	5	2024-03-04 14:11:50.216645+06	2024-03-04 00:00:00+06	Very best service.Sir.Satisfied I am	\N	{staff,driver,other,bus}	\N	t
56	1905088	6	2024-03-04 14:14:47.651765+06	\N	Reckless Driving and bad behaviour from staff.	\N	{driver,staff}	\N	t
57	1905077	5	2024-03-04 14:23:15.818015+06	2024-03-03 00:00:00+06	bad bus	\N	{staff,bus}	\N	t
59	1905077	5	2024-03-04 15:07:18.755845+06	2024-03-03 00:00:00+06	bad service	\N	{staff,bus}	\N	t
7	1905084	5	2023-09-06 13:17:05.786283+06	2023-09-03 00:00:00+06	I wasn't returned my exact change	\N	{staff}	Sorry, Tickets are bought via bkash so we would request to elaborate your feedback.	t
14	1905067	6	2023-09-07 11:10:55.061921+06	2023-09-05 00:00:00+06	Bus changed its route because of a political gathering & missed my location. 	\N	{bus}	Your feedback is being processed, we shall respond with actions soon	t
61	1905088	3	2024-04-23 00:50:00.398294+06	2024-04-12 00:00:00+06	rash driving	\N	{staff,bus}	tell driver when he does that	t
62	1905008	4	2024-04-23 01:41:46.506267+06	2024-04-09 00:00:00+06	Bus driver drove very aggressively and the helper stalled the bus to go elsewhere, for a long time in the middle of the journey.	\N	{staff,driver}	Noted. We will warn the staffs involved.	t
63	1905008	2	2024-04-23 01:46:26.163626+06	2024-04-20 00:00:00+06	The bus has no functioning fans.	\N	{bus}	\N	t
64	1905058	5	2024-04-23 09:42:37.389073+06	2024-04-11 00:00:00+06	 The seats were uncomfortable and the fan system seemed ineffective, leaving the cabin quite stuffy throughout the trip. I hope these issues can be addressed for future passengers' comfort.	\N	{bus}	\N	t
65	1905058	5	2024-04-23 13:53:46.812397+06	2024-04-11 00:00:00+06	driver behaved badly. \n	\N	{driver}	\N	t
60	1905058	5	2024-04-22 23:35:58.176154+06	2024-04-17 00:00:00+06	Firstly, the driver was consistently speeding, which not only endangered our safety but also made for a stressful and uncomfortable journey. Additionally, the bus conductor was rude and dismissive when passengers asked simple questions about the route and stops.	\N	{staff}	Thanks for the complaint, we shall immediately initiate a formal inquiry with regards to the aforementioned allegations.	t
9	69	1	2023-09-06 21:04:17.110769+06	2023-09-05 06:00:00+06	1984: Possibly the most terrifying space photograph ever taken. NASA astronaut Bruce McCandless floats untethered from his spacecraft using only his nitrogen-propelled, hand controlled backpack called a Manned Manoeuvring Unit (MMU) to keep him alive.	\N	{other}	Your feedback is being processed, we shall respond with actions soon	t
49	1905105	5	2024-02-06 12:31:17.667951+06	2024-02-01 00:00:00+06	The roads were bad.	\N	{other}	Road conditions are out of our capacity, we shall make sure to drive more carefully	t
66	1905058	7	2024-04-23 15:33:48.191963+06	2024-04-19 00:00:00+06	very rash driving\n	\N	{driver}	noted	t
\.


--
-- Data for Name: ticket; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ticket (student_id, trip_id, purchase_id, is_used, id, scanned_by) FROM stdin;
69     	\N	52	f	3ce03833-4888-4c3d-859f-0e9aca093eff	\N
69     	\N	52	f	eeaba65b-9455-4581-b5ff-ba49ca7915fd	\N
69     	\N	52	f	ce0146d6-714a-4327-bd7b-6003984c1a56	\N
69     	\N	52	f	ebede49f-fdcb-4ac4-a6ff-7eb95ef3fd31	\N
69     	\N	52	f	12cd7519-b638-46a5-b9da-0c900d506572	\N
69     	\N	52	f	efbb9a55-61d4-4630-b556-f0ee8ad9e1a6	\N
69     	\N	52	f	fdb17c28-a37a-4d2f-afa8-b6c91a96433d	\N
69     	\N	52	f	e05b75c1-ff87-4d3f-a382-63bc706063ab	\N
1905067	1539	53	t	ef57d389-4025-413c-8a8b-6b58f6554cd9	\N
1905067	1539	53	t	9e872f9f-2441-4511-ab93-2d6b086e2a09	\N
1905067	1786	53	t	61d85db4-de4e-462c-8177-17808603a033	\N
1905067	1786	53	t	4d7f86e4-b7a8-4129-ba28-eddd5a2ef24e	\N
1905067	1930	53	t	22dcd7cb-b7e0-4ea0-8a80-0ab6de5c0659	\N
1905067	2108	53	t	d004363b-770f-4cee-94db-b9cc072d5e7e	\N
1905084	2150	51	t	1f176532-22a1-46e3-bd99-bfa9cd299869	arif43
1905084	2078	51	t	34d6cf97-a2e9-4e04-8c85-6e31eb892b22	ibrahim
1905084	2150	51	t	c99b89c8-c00d-4c81-a5ba-5944c76b1c5a	arif43
1905067	\N	55	t	30307e1f-0db5-4f95-a649-d9edb2945de7	\N
1905067	2131	55	t	22d3ce6a-bf26-419f-9d3d-9ad4611fe192	\N
1905067	2131	55	t	a137e144-8b29-4815-b626-56aa3799379f	\N
1905067	2131	55	t	6af6d1cf-d15a-44c1-97c8-e86b89b8f6ba	\N
1905067	2131	55	t	f48aaf7e-6e6e-49fe-924d-f3c7e2ebfb29	\N
1905067	2131	55	t	c3662f59-339c-444e-b9ac-30ced7a6a2cc	\N
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
1905084	2313	51	t	da776040-456c-45fe-965f-bbff13269576	\N
1905084	2313	51	t	52b09c9f-643c-4998-bfad-5c39908f8ec4	\N
1905084	2171	51	t	5780cb12-a125-4ed7-ae41-0f392e2c2c34	\N
1905084	2171	51	t	1c89c3fc-b4d9-433f-9e63-5f4864ee6f60	\N
1905084	2171	51	t	14cd2a03-0358-4056-a4ed-1063de7bcb6d	\N
1905084	2171	51	t	bd08b692-6ecc-4d15-a4b1-0082375aa9d9	\N
1905084	2171	51	t	757a6b94-1bf7-483a-b95f-1ba5aea0cf4a	\N
1905084	2171	51	t	33dbe35f-2d62-47d3-9ad2-a65708e85fb8	\N
1905077	2358	54	t	4a0d345a-eff3-4821-a37c-68107a378201	\N
1905067	2360	56	t	4f920802-4bea-4e09-b697-49148fb8cc93	\N
1905067	3111	56	t	afbdf8ae-48fc-4dec-a3ae-651d02a9fc62	\N
1905067	3111	56	t	a3604a4e-7e51-4dd6-afd9-15e6fb81e63b	\N
1905067	3111	56	t	68c061d9-4b11-4462-8390-72e17fa7db40	\N
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
1905077	\N	72	f	16c47dbc-2462-407b-bf5b-f8d6a6ef4d88	\N
1905077	\N	72	f	02565843-9ecd-4e7e-852d-75b3cdbc3b2f	\N
1905077	\N	72	f	9812d385-e1de-496e-bbf6-fde4a07140d8	\N
1905077	\N	72	f	2a5b9a64-4b76-474c-a9c8-26d985a32887	\N
1905077	\N	72	f	53539277-9883-48c8-889b-5f29b351de8d	\N
1905077	\N	72	f	1d13ab2a-bcf0-4264-abe8-88b6bb2cbdae	\N
1905077	\N	72	f	3acdc86d-89d7-4e8a-b9c0-88d2a07c1e72	\N
1905077	\N	72	f	a251730a-1c9f-4103-a106-8b6f903d51c5	\N
1905077	\N	72	f	6b93bac4-549d-4fa6-a7cb-15d31644c151	\N
1905077	\N	72	f	d4eb5b72-1f16-4e50-a67f-df3333e8d2d2	\N
1905077	\N	72	f	d6631ab0-ea77-4515-9996-a0216dbb2039	\N
1905077	\N	72	f	a0a27da2-e497-4168-9a18-f84bd5deaf25	\N
1905077	\N	72	f	0d0100ab-a498-4a49-85a7-42272bcb4470	\N
1905077	\N	72	f	15402418-cdb4-4df4-996c-3685368cbce5	\N
1905077	\N	72	f	28d53b3a-4061-4dd4-9f2d-b32eacd5be28	\N
1905077	\N	72	f	6c1d343e-6809-4b36-a4dd-caeb88b6dfd2	\N
1905077	\N	72	f	7e51223c-d2cb-451a-9db3-f448b551a713	\N
1905077	\N	72	f	c454ff36-7b51-4894-afa1-6a1daab23203	\N
1905077	\N	72	f	eea2a291-659e-4fe8-b9e4-571428adcc57	\N
1905077	\N	72	f	0e77b8e7-5029-4352-ab87-ef7986651028	\N
1905077	\N	72	f	9e6e55b1-253f-4384-b2fe-d3b52cd436b7	\N
1905077	\N	72	f	de745392-cacc-41e3-bfce-9c0d77a90516	\N
1905077	\N	72	f	9d4b9900-cc06-40bf-b3ef-91a81f5a9fd5	\N
1905077	\N	72	f	6946a871-f77d-40e9-9ff4-ca95c5afa995	\N
1905077	\N	72	f	6cea906b-7807-4306-81bd-e11d3f4a7af6	\N
1905077	\N	72	f	1ddcecc9-7a81-40fa-b5e0-daec7b95b0ea	\N
1905077	\N	72	f	9b5967f7-dc97-4da7-8a0b-5cb6b0c9a5b3	\N
1905077	\N	72	f	31cb72b7-4288-4c13-9465-e435ac9ed9f1	\N
1905077	\N	72	f	25070561-51b6-4b9d-a86c-c7fbf5ec3f5f	\N
1905077	\N	72	f	541af8d1-512e-4619-ac40-b857e186d41f	\N
1905077	\N	72	f	26cb7929-1a59-442a-a1a8-6c4a3f23e6fc	\N
1905077	2695	72	t	18695bef-ad15-4793-bcf1-1e1f5b6c1e81	\N
1905077	2695	72	t	fac5532b-2bc5-42d6-907b-2992d5c3275e	\N
1905077	2695	72	t	eb061514-e288-4f2a-984b-3eb16e8b8d46	\N
1905077	2695	72	t	4a0cb547-8571-4c32-bd0b-18ada6c9d590	\N
1905077	2695	72	t	519f093e-ce61-4b0d-96e9-6d5a94d86631	\N
1905077	2695	72	t	8731e07d-2c92-4c17-998f-b36bc651c019	\N
1905077	3111	72	t	36071958-7610-438a-b9d3-9bcd3b100c92	\N
1905077	3111	72	t	380259ce-2a42-4046-a05c-5b957e36b71e	\N
1905067	3111	69	t	c7d481ae-4c8f-4897-a167-3b61c1013e64	\N
1905077	3111	72	t	a7585b18-79bb-4f3e-813c-6d8c76a54aaa	\N
1905077	3111	72	t	9a10391c-ddbf-4689-9498-83524c96d5fa	\N
1905077	3111	72	t	6ac9c27d-fe78-4ae6-b94d-da8c8e3a758f	\N
1905077	3111	72	t	65883465-8da9-49c5-a581-024207c0a11f	\N
1905067	3111	69	t	b883592c-d5ec-416f-b388-a3264ef0d396	mahbub777
1905077	\N	76	f	af83be9a-7479-4c44-93e4-3d62d8543c0b	\N
1905077	\N	76	f	1c2710cc-f796-4cf1-b242-6bf27ee8cd5f	\N
1905077	\N	76	f	1cdc8bdd-80ba-4c29-bb2f-75a4e27f6eb3	\N
1905077	\N	76	f	94ef5f1d-25bf-46a1-afe1-8052823f7778	\N
1905077	\N	76	f	8bdabc93-500a-455e-9290-71fe3da64f97	\N
1905077	\N	76	f	721eab1e-f480-4523-97a0-ed11ea385c17	\N
1905077	\N	76	f	302b623e-a665-4029-bccc-a681b66260c7	\N
1905077	\N	76	f	35b67578-9c78-48bd-877b-74c24ed5c84a	\N
1905077	\N	76	f	e5eb1e6c-abf1-42e1-a6f2-a6e06ca9d994	\N
1905077	\N	76	f	64ad2fa5-858d-49cd-b3eb-3adcbaf0eef2	\N
1905077	\N	76	f	81a76a4c-2995-47cb-a3d5-443e6433ab69	\N
1905077	\N	76	f	101551ee-b8a5-4180-b0b6-1fff552eaf69	\N
1905077	\N	76	f	5cda0663-5ed2-4ca1-970d-34a4e062525f	\N
1905077	\N	76	f	d390fe8d-88bf-4baf-ad73-7e17aeb6ce7e	\N
1905077	3374	72	t	c48f583f-50ca-42dd-905c-3614167e61ee	ibrahim
1905077	3667	72	t	0bf2e40a-4774-4219-834d-f4cfe991c18e	mahbub777
1905077	3714	72	t	a7889029-7f9e-475c-928a-0d5703bed54e	nizam88
1905077	4124	72	t	2229134c-1581-463e-9a20-2a2219468981	nizam88
1905077	4124	72	t	f93f2c23-4114-43ee-beb3-54f0e25a60ed	nizam88
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
1905069	\N	70	f	185b0ac7-a981-4a0c-8d1d-1ee426ef3bfe	\N
1905069	\N	70	f	447d8304-3c6e-46be-aceb-643dfda27644	\N
1905069	\N	70	f	02ca1122-f459-4649-b6ac-46b29ca1ca57	\N
1905069	\N	70	f	fffd8cbf-4433-4118-8206-6e1fa5d109dd	\N
1905069	\N	70	f	c60c3783-0008-4c9b-94d3-13c6eababc08	\N
1905069	\N	70	f	e39cfeff-1cf7-462f-b74a-c05b03ac6186	\N
1905069	\N	70	f	2d174cc8-7672-4129-adcf-6407b87a3645	\N
1905069	\N	70	f	23b6cb74-5748-489e-9bc9-7e1646cd7a4f	\N
1905069	\N	70	f	227e3d9a-ff61-4542-ac5f-5a9b6e5e03cf	\N
1905069	\N	70	f	b3a09633-9f02-495a-9748-a727823ff727	\N
1905069	\N	70	f	409c3800-7f65-40f4-999c-caa7ac93de69	\N
1905069	\N	70	f	78865737-21cc-4bb3-bacd-0aade7f310ae	\N
1905069	\N	70	f	03f772b6-6b9e-4d60-b96f-9794762d236a	\N
1905069	\N	70	f	5e27ff17-95e6-434c-b22f-9f90ea7ecbef	\N
1905069	\N	70	f	db645a28-92be-4e58-827c-cb0deec7a8d1	\N
1905069	\N	70	f	ebe6e4c4-b991-49bb-9636-3fe1927bee3b	\N
1905069	\N	70	f	585f695d-be2b-41bf-95a3-fc276c85088f	\N
1905069	\N	70	f	f741e4bf-e7da-4e72-913f-6ef8cbfe5ae1	\N
1905069	\N	70	f	1aa44eba-5f46-42a7-b2b3-36ca6962bf95	\N
1905069	\N	70	f	96035dfc-125e-4d16-9e8c-377679c8db40	\N
1905069	\N	70	f	a20b8955-9b8c-482d-b0f8-49c78db2c85d	\N
1905069	\N	70	f	73590e0a-8a9c-48c1-9dac-445c1c31ba1e	\N
1905069	\N	70	f	35edeaee-a4c3-4b57-a366-8a46406c1097	\N
1905069	\N	70	f	3225e8d8-a74c-43f4-98ee-c8138c831a9b	\N
1905069	\N	70	f	a7c8f57e-f1d8-482b-a025-c26587461178	\N
1905069	\N	70	f	b623cc68-a506-4c8c-8a51-bd40d2e1725c	\N
1905069	\N	70	f	4a208fbb-3b13-4332-b8ca-708605e579ea	\N
1905069	\N	70	f	1d5b95f4-195c-4685-824e-47aa267ef4cf	\N
1905069	\N	70	f	f01278f9-7553-487c-8ce0-5a1d6df1488c	\N
1905069	\N	70	f	70767a5e-a088-45c0-866c-d7863d77cdee	\N
1905069	\N	70	f	e096a2ba-37f3-4515-acd0-dbf603d2fcdf	\N
1905069	\N	70	f	f1589da1-9cfe-4918-95c4-09a98a483526	\N
1905069	\N	70	f	4e6d1150-bb04-4d14-9c22-c80b001e0446	\N
1905069	\N	70	f	e8269f9e-be97-4f57-a964-af0e6cd0650b	\N
1905069	\N	70	f	3ae54169-0897-4de4-89af-24759f147c59	\N
1905069	\N	70	f	b08b7da2-0225-4742-a6c9-0672dd56454c	\N
1905069	\N	70	f	be182354-1952-4a73-a80a-c81670145e3f	\N
1905069	\N	70	f	5b443f20-e92b-4ea7-b476-2c062834f7da	\N
1905069	\N	70	f	3135ff11-8113-443b-8e60-fa84cef56c85	\N
1905069	\N	70	f	3d6e94e7-ad86-4b21-841c-dc4f2b98b87e	\N
1905069	\N	70	f	f5015d80-bcc5-4b00-9417-fbd4f0d8c19f	\N
1905069	\N	70	f	666851f4-410b-4b55-adc8-29026e04df0c	\N
1905069	\N	70	f	6ac7ebd5-fafa-47e1-83bb-a086f2525a06	\N
1905069	\N	70	f	59904da1-af14-4f08-8f3c-eac7e438eedc	\N
1905069	\N	70	f	bf0a46bd-7a49-4281-a36e-e3689b0049ff	\N
1905069	\N	70	f	579045fd-d741-449d-a11b-81f61def25ce	\N
1905069	\N	70	f	ffceb6a1-5839-4f4e-b76c-1ca5808d0132	\N
1905069	\N	70	f	9dce99f5-b45a-4a93-a232-d0617bd61c01	\N
1905069	\N	70	f	5b96ae54-2c58-405a-9df2-bcebd884d09b	\N
1905069	\N	70	f	3e78ad37-b9e1-4486-aa4e-08710cc741be	\N
1905084	2171	65	t	a2f21a02-f7da-4c77-a62f-d0332d3e891a	\N
1905084	2171	65	t	314e8ed9-f8de-4c03-b5c7-769ac444b381	\N
1905084	2171	65	t	f20300ea-cddb-4430-9061-0ca46ecd7af9	\N
1905084	2171	65	t	eb1895c3-ee37-4e65-a64a-267dd776a006	\N
1905084	2171	65	t	4c0f9c86-0b74-4769-86ea-9a697799407e	\N
1905084	2171	65	t	08b8e348-a724-4896-8162-924ffcfb3bea	\N
1905084	2171	65	t	24934308-342a-4608-8205-d483db8413a9	\N
1905084	2171	65	t	3b9cc5ff-1223-447c-9826-66ef41e525fc	\N
1905084	2171	65	t	176af4c7-a7e0-4eb1-8d0e-426f60f0e8d6	\N
1905084	2360	65	t	00eabb1d-06dd-4aca-a79a-b491ab4c3fbf	\N
1905084	2360	65	t	ee914d49-e94f-4f8a-8324-cfc0fcdd2933	\N
1905067	\N	73	f	2efff326-6522-42bc-806e-f07ee20cb316	\N
1905067	\N	73	f	1645dcdf-466a-40d5-8394-bbcc068c2734	\N
1905067	\N	73	f	896b2db7-f781-4770-a0dc-ccd011390aba	\N
1905067	\N	73	f	aa98695e-24fc-49ca-89c2-2a4f5c50a7d5	\N
1905067	\N	73	f	12001af0-63e6-4aee-bd62-c4ad3b7d8737	\N
1905067	\N	73	f	ef55a29f-7c4e-4a16-93db-fcad52d9e062	\N
1905067	\N	73	f	316fd98f-527d-4b38-a44e-0457fadf13e2	\N
1905067	\N	73	f	a0af9c57-5ca6-4081-a2b7-fdb778668b76	\N
1905067	\N	73	f	ef596bf4-209b-4ab5-8ba2-0e53fddb9d90	\N
1905067	\N	73	f	135db085-deb7-43cc-82d9-2d574401949f	\N
1905067	\N	73	f	1174a51a-b21c-4f32-aa2c-bbba2962c2ca	\N
1905067	\N	73	f	767a84cd-36f1-422a-b6d3-1d1b23378e3a	\N
1905067	\N	73	f	0d7a9d55-cc44-41b7-bde4-58337c3915b7	\N
1905067	\N	73	f	cffcbe1b-4d55-4af6-85e5-94cfe32b79f6	\N
1905067	\N	73	f	9bbddfcb-3f15-442d-ac8b-895d06489c5c	\N
1905067	\N	73	f	6694f87e-7411-4838-978e-9b8626ee0ff7	\N
1905067	\N	73	f	a8ed5356-e81e-4b58-8006-2ba3f792203f	\N
1905067	\N	73	f	3aa3aab4-8d0b-4ebf-aff6-da9837ad32da	\N
1905067	\N	73	f	56ac3ef0-d06e-4a5c-8371-7b87c801d173	\N
1905067	\N	73	f	d02e00e3-7193-468e-baaf-607646d4d30f	\N
1905067	\N	73	f	7a705d62-d5cb-4b2f-a50b-5c33e6e4be15	\N
1905067	\N	73	f	696e0762-7568-40e8-abd5-99ed6e151eac	\N
1905067	\N	73	f	05995fee-fc19-44da-b8a0-d96408194c80	\N
1905067	\N	73	f	f677bc65-ed4f-4807-af82-3feea361ab8d	\N
1905067	\N	73	f	51445e26-f69b-4379-8d3e-35537f96de86	\N
1905067	\N	73	f	816969ee-9470-420d-82b4-c570a961d07c	\N
1905067	\N	73	f	d81feaac-08e5-460a-aa1f-088dccc42135	\N
1905067	\N	73	f	770197d2-b58c-4fd2-90d5-bf2df749e1e0	\N
1905067	\N	73	f	f7be4f49-3e0a-46fd-87d1-d1da29b5f74a	\N
1905077	\N	76	f	eefcbe2c-035c-454a-9518-11168328b794	\N
1905077	\N	76	f	9b96b027-9f80-478b-86a2-75354b7bae50	\N
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
1905084	2171	51	t	cbda569b-4da6-454d-a7d9-c98308654a08	\N
1905084	2171	51	t	3ea017a7-f998-4307-80e9-c731d7d88868	\N
1905067	\N	73	f	e6917b71-e100-499c-a5d6-aaee2e954a84	\N
1905067	\N	73	f	e85ae9dd-48c6-4474-be56-7bb426924ec7	\N
1905067	\N	73	f	49236d7d-2e55-4132-befd-11f24b67e200	\N
1905067	\N	73	f	081078fc-c900-46b2-af3f-dc586888260d	\N
1905067	\N	73	f	871ae276-13c4-4d89-a65f-3714389f99ef	\N
1905067	\N	73	f	cacf307f-4308-446d-b018-51abd63cc538	\N
1905067	\N	73	f	ee6f6ce8-fb59-4532-a9c2-4b0222928cca	\N
1905067	\N	73	f	37fd4a43-3b76-45aa-acae-26547c392f8a	\N
1905067	\N	73	f	e97dc65c-2e97-4a12-9ff2-07b580182b2b	\N
1905067	\N	73	f	f79d8a9f-c203-4481-9f72-c938094fa18a	\N
1905067	\N	73	f	8ce57e76-310c-4e0c-853f-331f4bad0c5b	\N
1905067	\N	73	f	43d7d70a-8fa9-4709-8e7b-526ccbb1c777	\N
1905067	\N	73	f	7e7dd13f-8c99-421b-9476-e0c99c053a06	\N
1905067	\N	73	f	b14cfe21-8f02-453c-852f-5c48f829a354	\N
1905067	\N	73	f	e5a26e92-1f4a-4ddd-8db4-ac7c448de996	\N
1905067	\N	73	f	e41a6c1b-051d-4496-b6df-70a0d4d79e51	\N
1905067	\N	73	f	682983d3-0225-4b10-a7a4-bc90d2944532	\N
1905067	\N	73	f	315e1706-c057-4e0b-8d42-bfca625a0528	\N
1905067	\N	73	f	4e3baff5-d84c-4834-9900-4fdab849c930	\N
1905067	\N	73	f	48786e3c-97fe-4751-ba5e-b92738df1f41	\N
1905067	\N	73	f	200988ad-c7e4-4ee7-a868-b24fdd8c9298	\N
1905088	\N	74	f	1bd9fd87-12b4-4de6-bc27-2878c944e699	\N
1905088	\N	74	f	1d1289fd-f402-4da4-8962-906f1cd7ff51	\N
1905088	\N	74	f	9d457681-c7b4-4678-a03e-9e57b8427fa0	\N
1905088	\N	74	f	fd7a16d9-548b-4144-ad1d-00073c24d466	\N
1905088	\N	74	f	c6819956-02de-4277-9d16-67d9a71748ba	\N
1905088	\N	74	f	d40557c6-c30e-4a12-be7d-892dae64c325	\N
1905088	\N	74	f	50532f51-39c8-4cb2-abba-094f24b24e8b	\N
1905088	\N	74	f	f7af5cf0-1ed7-490c-8388-9b11774ce1d9	\N
1905088	\N	74	f	2fc39569-e29b-4fce-a2b9-060a72fd32c2	\N
1905088	\N	74	f	8af29d0b-b118-4c81-80c5-08c49de18274	\N
1905088	\N	74	f	4113b912-97a8-47b2-a1cf-721e2206e2ac	\N
1905088	\N	74	f	06ca9400-2064-43d1-85a3-ee4ab436bb8c	\N
1905088	\N	74	f	9072a4b2-65d1-445d-9096-b96607f784fd	\N
1905088	\N	74	f	4ff59022-7002-486c-97bb-1c38a80fdc44	\N
1905088	\N	74	f	15b19697-9daa-4329-9296-2f5b3ec446b6	\N
1905088	\N	74	f	0a8e6516-0579-433d-aefe-cb05420992bf	\N
1905088	\N	74	f	6ac404ad-91e2-458d-b01a-4d0d679fc7d1	\N
1905088	\N	74	f	fe21e476-c441-4430-b09a-91a3defb9590	\N
1905088	\N	74	f	6315d4dd-a683-4871-a7a0-69e59babdb9e	\N
1905088	\N	74	f	ee83df54-8ecc-4154-a50a-9702505b2c02	\N
1905088	\N	74	f	d395221b-5296-4690-9eb5-2d7835b0fc9b	\N
1905077	\N	67	f	351fad02-9f20-4224-9f25-438f515f144a	\N
1905077	\N	67	f	c1056d36-f406-4c64-9bdd-7b77dcb97963	\N
1905077	\N	67	f	777a17c0-5194-4e18-a9e7-be4a9522ed4e	\N
1905088	\N	71	f	0ee24cfe-c898-4b22-b1c2-cd474e76ed8c	\N
1905088	\N	71	f	ec3fb4ca-1fad-45b5-ac63-934ef30063d8	\N
1905088	\N	71	f	f2653ef9-91bf-429a-a9e8-339e0d82e67e	\N
1905088	\N	71	f	70d10e55-649f-408b-ace1-06f1e83c14da	\N
1905088	\N	71	f	59f7ec22-3d3f-4730-bb52-8c55e63ada94	\N
1905088	\N	71	f	3ec4352f-e987-4cc7-b7ff-e9a68b349d86	\N
1905088	\N	71	f	f35d7aa4-9816-4f36-a83c-a6ac1a99d01a	\N
1905088	\N	71	f	9dcbd97d-472e-4f09-abfc-2b34e6b244ad	\N
1905088	2472	71	t	45d7b81e-828c-42d3-8b87-2059368d062a	\N
1905088	2472	71	t	27bf0996-b806-4c91-95c5-daf8faf66ff1	\N
1905088	2472	71	t	45f1b33e-634e-4c69-b584-0c2d671155f6	\N
1905088	2472	71	t	a11919d6-177b-43e1-9d6d-920349f94c0b	\N
1905088	2472	71	t	3530b47d-60c0-43bf-aa5e-dc1b73de117c	\N
1905088	2472	71	t	fd7989aa-6286-422d-9b8d-7b8d63cc9ce4	\N
1905088	2472	71	t	5529bcb3-5bf5-4510-be99-2f09c4f4d1bb	\N
1905077	2358	67	t	bc0eec36-0f1f-4e0f-b4c8-975026dddcf9	\N
1905077	2358	67	t	8c1f761d-84ee-4bc6-bd86-bf2c77d0bb25	\N
1905077	2358	67	t	77b5f702-69b9-482e-ab5a-67270e7e2fad	\N
1905077	2358	67	t	0a88b263-c9a0-4161-af30-32b2a05091e4	\N
1905077	2360	67	t	e48d0895-a512-4527-8354-9645ad75ccf5	\N
1905077	2360	67	t	4b00bb71-c43b-4992-9728-acab7abbc51b	\N
1905077	2504	67	t	ce6e89d7-c35c-475c-9248-4ea9de5e2245	\N
1905077	2569	67	t	8557cc54-5dd3-4f0f-8f86-c14b37e16682	\N
1905077	2570	67	t	1049d5b4-a1d0-482a-b551-a6fe5ba7c8cf	\N
1905088	\N	74	f	d72b3e20-4316-4998-aeee-3369e4671f0b	\N
1905088	\N	74	f	c8fdba48-dedd-4d5f-9fc7-340da6d5ede7	\N
1905088	\N	74	f	f0a49123-4b3d-4598-9a19-90fe6a4e9a16	\N
1905088	\N	74	f	0ae568d0-639a-45d3-99a6-6cb66db5382a	\N
1905088	\N	74	f	1179dc9d-22b3-4390-920e-46b554e983dd	\N
1905088	\N	74	f	de1aad6b-da36-409a-a1ec-860c7a3fee6f	\N
1905088	\N	74	f	805eded7-3b0d-4e6c-a3cc-cf8f31ce2aa0	\N
1905088	\N	74	f	b88dc55b-ad86-4928-a99e-c1370737d369	\N
1905088	\N	74	f	b8ab845f-4933-4e71-b61a-2cec0d1afcef	\N
1905088	\N	74	f	a6bfd62f-dcb2-4646-bb70-48cf14192bed	\N
1905088	\N	74	f	dcc599b0-ee44-4b0b-a6f6-acdc88ec5647	\N
1905088	\N	74	f	6a6a67a6-39c4-4631-a690-0e5724c58834	\N
1905088	\N	74	f	87f6fd12-ba4d-4398-b932-dd92d5c18185	\N
1905088	\N	74	f	47c14b3b-c800-489b-8dbb-4d9d7ca1e801	\N
1905088	\N	74	f	4075cb7e-f260-4b1b-96ee-0d5c5b7f0a4e	\N
1905088	\N	74	f	ecd0e1b4-bd3f-4494-a505-f68b52bc8bf8	\N
1905088	\N	74	f	29ebe263-4a84-43d9-aafa-b6f60989d7a1	\N
1905088	\N	74	f	9f2a223d-a2b7-46a6-9fb7-f9b17b74c245	\N
1905088	\N	74	f	0dd5eca1-c1ce-4c27-b2c7-98bc919dd3be	\N
1905088	\N	74	f	f94719bd-e349-48a4-aafc-aa98e0fccd62	\N
1905088	\N	74	f	6aa92c5e-b79d-47fb-a095-269b6d8bb958	\N
1905088	\N	74	f	3fbe5b54-b851-4d36-9beb-9286ba6d9a65	\N
1905088	\N	74	f	5b9c8857-7e2d-411a-8ab0-93413e1aef3e	\N
1905088	\N	74	f	954d725e-2e22-40c4-adce-3533cef975f3	\N
1905088	\N	74	f	112bbfb9-cee7-451f-8ccc-d2ad138d9565	\N
1905088	\N	74	f	ecbcbacc-e5ee-482b-a403-74dd3b8a238c	\N
1905088	\N	74	f	9da50de1-49e8-4dfa-a7cb-4d52df26c9b8	\N
1905088	\N	74	f	ea4e06d4-b422-40d5-a8dc-af76c78f5fc4	\N
1905088	\N	74	f	fc79b0dd-f937-486b-b2f0-ec5ab1a6dad1	\N
1905077	\N	76	f	9c292ce0-e1f7-46bf-8444-bfa40e68919a	\N
1905077	\N	76	f	089ab22e-ef75-4570-9607-a0f44601b707	\N
1905077	\N	76	f	6cc4c5b4-82fd-42de-94ac-8dee9aa248f5	\N
1905077	\N	76	f	207e6759-b3bd-4078-9498-8b85ed906b64	\N
1905077	\N	76	f	435059dc-3e09-4a88-8062-1e30d02cd98c	\N
1905077	\N	76	f	8739b614-6da1-463d-973d-08473e934d29	\N
1905077	\N	76	f	f0cf70d7-6e0d-4a93-9419-941b2f4cd184	\N
1905077	\N	76	f	63fe2238-21d2-4c2b-9928-7881b92a1d20	\N
1905077	\N	76	f	895b329e-068c-42a5-bd1b-78936255631d	\N
1905077	\N	76	f	e61fe2bd-4554-4929-8ccd-ed5b38a83670	\N
1905077	\N	76	f	a6c253ac-053c-4c1e-ab48-4c36ebf44b3c	\N
1905077	\N	76	f	a452310f-8493-409b-b4a3-6d6001a787bd	\N
1905077	\N	76	f	358c3e63-6384-49ca-89d8-5b875a2d1334	\N
1905077	\N	76	f	676de1ee-1be0-4a7e-be42-db438a54e186	\N
1905077	\N	76	f	cde7850c-935f-40c2-b4e1-fa0a7dd84ab1	\N
1905077	\N	76	f	bfff8d19-04ee-4abe-8664-dd1348dcd62b	\N
1905077	\N	76	f	ee5966f4-2211-4994-b8a5-ac86ef5bda75	\N
1905077	\N	76	f	0f5d487c-5bc2-49a4-819a-d39e72396304	\N
1905077	\N	76	f	beb7cbf8-0285-4306-8f7b-c535bf4bdff3	\N
1905077	\N	76	f	ff8ac66a-9d9c-42d6-8b72-18a845dea52d	\N
1905077	\N	76	f	849573f1-38d0-4e30-939d-ce3a217afd98	\N
1905077	\N	76	f	44b5e6c0-96c5-40fc-98e1-72cc3896b78b	\N
1905077	\N	76	f	c7b60b14-84be-4ee6-a0d6-f14d656b9c31	\N
1905077	\N	76	f	88cb4633-2d2f-4f35-8b56-7b4d68bfbbfd	\N
1905077	\N	76	f	28e5b4d0-763b-4b9c-8d3c-6807f1d14dea	\N
1905077	\N	76	f	5ed6080b-33fc-4af7-9e98-2392fc0dbc00	\N
1905077	\N	76	f	dcdd1ca3-52d2-4b06-a5d9-679294e02416	\N
1905077	\N	76	f	d7e5e0ff-d8d6-46b5-95fc-85b7cfdb03fd	\N
1905077	\N	76	f	95334ac9-e940-4c8a-9d3a-1c8d43a8382e	\N
1905077	\N	76	f	87a62eae-c8b7-44cf-b96a-1e3975381226	\N
1905077	\N	76	f	6df69371-9899-4fdf-a425-a2907d92bf50	\N
1905077	\N	76	f	e49eb3f7-afff-4810-ba8b-b4b9cf6aa073	\N
1905077	\N	76	f	5b317b2b-3947-4ca0-ad7a-f45ebbf257fb	\N
1905077	\N	76	f	9dc55e61-ef23-436c-8c4a-313c975d558d	\N
1905077	3374	72	t	89d51a45-f5f4-484a-9f39-4f9d3b91edbc	ibrahim
1905088	\N	77	f	9cedd6c1-e3cf-46dc-9801-ea7c9eb0ea2c	\N
1905088	\N	77	f	ebed97a6-76df-412b-bbd0-1035f116676b	\N
1905088	\N	77	f	f9392655-0057-4d39-9701-145c14b7fa31	\N
1905088	\N	77	f	9d941b3c-d683-445c-94f5-eefb8de9914a	\N
1905088	\N	77	f	87d2fcfd-8590-4884-a328-e3bacac38f54	\N
1905088	\N	77	f	728f222f-95c9-4a7c-8886-112adf42ca52	\N
1905088	\N	77	f	9f656d73-2946-4142-a0ca-57ec1cae3e7e	\N
1905088	\N	77	f	c6ceacdb-e735-4417-b4c3-c89cdd155197	\N
1905088	\N	77	f	76d0a4f6-0943-4c7d-83d7-9070c95bdd2c	\N
1905088	\N	77	f	de1de29f-a36b-438d-b9f0-380445310b2d	\N
1905088	\N	77	f	9f81cd02-df2c-4b1f-8c1f-76fd265c15f2	\N
1905088	\N	77	f	7ebe07ec-7959-49b1-9acd-26ea30bbe21b	\N
1905088	\N	77	f	af0d4e40-e2ed-451b-89e3-8ab874342987	\N
1905088	\N	77	f	0e287973-1e2b-4a05-8818-1203a12ac899	\N
1905088	\N	77	f	8482943b-6dbf-48ab-912b-356a44046a6d	\N
1905088	\N	77	f	b685144f-bacc-45a1-bcf7-790e879ad5bb	\N
1905088	\N	77	f	9be08936-0d5a-42d8-80bc-545f5dcb555a	\N
1905088	\N	77	f	130e3bf4-9c1b-42a4-9176-f426cb4347ce	\N
1905088	\N	77	f	3d2bdd33-0501-4b4b-8b0a-d1d4ba1db732	\N
1905088	\N	77	f	ef4c2a7d-1a01-4459-b34d-0ac664d8588c	\N
1905088	\N	77	f	812edabd-76d7-46b9-9d47-6e97a30e7fca	\N
1905088	\N	77	f	cb90d6bd-885a-40f8-a62b-52f41571c187	\N
1905088	\N	77	f	13876eb4-e095-4843-bed9-b7cfb89a9355	\N
1905077	2358	63	t	bf629f67-42d2-4825-9d05-0c4bfd0517c7	\N
1905088	\N	75	f	3669a5ad-408c-42ce-9d47-5ff8e4e0e988	\N
1905088	\N	75	f	e76e0d59-8681-4bef-a02e-61abda89592a	\N
1905088	\N	75	f	2327e950-8db0-4992-8b02-4f3394bbd831	\N
1905088	\N	75	f	75bbdeb4-2425-40ed-8298-123ed09f21f0	\N
1905088	\N	75	f	6716ea88-0a41-4224-bdd8-2eb98acddac2	\N
1905088	\N	75	f	c7c5e4b7-022a-4496-a9cd-48951c5b7a5a	\N
1905088	\N	75	f	ed9200c9-a58f-4b9f-bc96-f321f825f993	\N
1905088	\N	75	f	98d59676-d209-4cb7-a366-9c0f440fbf09	\N
1905088	\N	75	f	6a05e6ee-c791-43f3-bd6a-01a25cba85e3	\N
1905088	\N	75	f	d4b0db6a-1a36-4c25-8840-ef47ecd7caa8	\N
1905088	\N	75	f	d4955e9f-1a7f-447a-9cd2-cf43cec8d4ca	\N
1905088	\N	75	f	8fd970b7-9247-4b26-bd59-8a91287a2174	\N
1905088	\N	75	f	c40e539b-e7f9-44d8-8740-5cffe1aec928	\N
1905088	\N	75	f	596432e6-28f0-4eea-8be1-3d83e21a723e	\N
1905088	\N	75	f	f45ac794-f7c6-4430-afdf-09982470e04e	\N
1905088	\N	75	f	10a80a71-cc7f-4207-b712-bfce1f5feabc	\N
1905088	\N	75	f	258721d3-f1c6-4b88-a94d-6d18e014f8b5	\N
1905088	\N	75	f	52804b0b-4c59-4c01-b80f-37a43068ebe5	\N
1905088	\N	75	f	307e48c6-c953-4301-bdcb-6575ee655d1e	\N
1905088	\N	75	f	c748ce7c-3b07-49f5-a733-45d75f69326e	\N
1905088	\N	75	f	a7dc68ed-3b83-4d26-becb-fca62e35a102	\N
1905088	\N	75	f	f1bd007e-aafb-4361-99c9-6703e6cfaf4a	\N
1905088	\N	75	f	9dc54cb1-de86-485f-999a-f0eeb987d26d	\N
1905088	\N	75	f	cec130ce-3c64-4fdc-a240-430b8ebea841	\N
1905088	\N	75	f	738a7cd3-6be4-4a9d-958c-0930b05efa77	\N
1905088	\N	75	f	d87c7c1c-ced1-4615-a295-60544f820b99	\N
1905088	\N	75	f	aee54630-b657-49ed-a884-ede1bf7504f1	\N
1905088	\N	75	f	c0247f73-8302-4f34-bbce-3e64c825eff7	\N
1905088	\N	75	f	6d506ea0-508e-4459-995a-0a373a307f17	\N
1905088	\N	75	f	ae5f5a28-49c6-45eb-a098-e3f706f2c861	\N
1905088	\N	75	f	ffb744c8-7797-4aba-92cd-6b9f2f8180c1	\N
1905088	\N	75	f	2ad578c7-2c52-471a-b981-822d1f59b8b1	\N
1905088	\N	75	f	0b355434-06a4-4f3a-930f-2c60f911f4ec	\N
1905088	\N	75	f	6e5c9429-bbf7-4039-8504-1267eadca1e5	\N
1905088	\N	75	f	f1727181-2d4b-4b57-b593-55cf142c02cf	\N
1905088	\N	75	f	44790590-378d-4430-983a-1022035c1539	\N
1905088	\N	75	f	47c1cf04-bbc6-4fd8-ae31-042ed14608ef	\N
1905088	\N	75	f	1fac140f-1e27-4e4d-a01f-e46329a62636	\N
1905088	\N	75	f	bd8e178d-adbe-4ad3-886f-3502ca59ab00	\N
1905088	\N	75	f	373b9b19-a44a-4d57-af34-573f929fd52e	\N
1905088	\N	75	f	81f8d4ba-937a-4c4a-aac9-5fec89ba2832	\N
1905088	\N	75	f	24e9e5b1-86c4-4833-87ad-0ae4cbe57de3	\N
1905088	\N	75	f	47234ea9-d663-4d67-a60d-73f03bfaa6d3	\N
1905088	\N	75	f	959844a6-150a-4295-bebb-4c98b35decf1	\N
1905088	\N	75	f	882f109b-ab01-42b5-aa44-726d20835463	\N
1905088	\N	75	f	f0508c07-53b4-41bf-a459-cd0272aa4663	\N
1905088	\N	75	f	ccce2689-4ecd-43e5-9850-f4b10020f889	\N
1905088	\N	75	f	e69bbd6b-3ba4-4e33-9a4c-84c949cc7b29	\N
1905088	\N	75	f	b391c39a-3857-42bd-9290-24395375bbeb	\N
1905088	\N	75	f	6845baf5-4b96-468b-9a03-97094dfa2045	\N
1905088	\N	77	f	84f8d669-a205-42a3-9676-1ab25b3c328c	\N
1905088	\N	77	f	2ee5c76b-a082-40ba-879c-f4c297ec52f6	\N
1905088	\N	77	f	ddd1bc84-1b54-4f01-a8fd-e5ba9fa0f7d1	\N
1905088	\N	77	f	6abf55e4-58f8-4571-a826-26c6ce228bd4	\N
1905088	\N	77	f	ed837036-ee7a-4085-b7bd-21589d60263b	\N
1905088	\N	77	f	9cda1b6f-15ef-4c16-965d-bb6da626a1e5	\N
1905088	\N	77	f	9044c775-cbb9-4086-85ca-f7866f378818	\N
1905088	\N	77	f	8a372e60-2071-4570-8807-1b64bf7f8a7d	\N
1905088	\N	77	f	e38d6709-9f77-4f6a-8add-fe8f06ac4f0e	\N
1905088	\N	77	f	0f219316-35be-4880-84a2-3f50a3c7bf47	\N
1905088	\N	77	f	cdf3a014-24d5-4f88-ae5a-ab5f874e50e6	\N
1905088	\N	77	f	1219b33c-1ded-4a05-b02b-46439979f52e	\N
1905088	\N	77	f	7558f223-4a50-4a34-a6d4-d2fb09f5c093	\N
1905088	\N	77	f	dfda88b0-71c8-48b2-9c08-5bb99e1a9717	\N
1905088	\N	77	f	0a1e6230-80c3-4dba-b0b7-a06cfbff89c8	\N
1905088	\N	77	f	98caa9c3-265a-497b-b196-c6ea2579c3d8	\N
1905088	\N	77	f	afbdfa60-12b5-4d3a-b320-6ed28ff957d6	\N
1905088	\N	77	f	77dc515e-f42c-404f-ad0b-dbfc96be9dbe	\N
1905088	\N	77	f	25defa94-9696-46d8-8b28-450639c8eac1	\N
1905088	\N	77	f	0b5533fd-0ba5-4811-93ef-ad8d7b3f877c	\N
1905088	\N	77	f	b114d54e-9c36-489a-a806-f16a4f18bf2a	\N
1905088	\N	77	f	7dea1133-eb7d-429b-a111-af68bb17de01	\N
1905088	\N	77	f	d6bc9522-e1cf-4f3d-a162-e5420f265a03	\N
1905088	\N	77	f	98b6c31a-c333-4484-92d3-27b69fa2be36	\N
1905088	\N	77	f	47795cdb-0db7-4579-9486-11eaa90a2bd0	\N
1905088	\N	77	f	839dadd0-71d0-4d26-85a2-c7a5682d837d	\N
1905088	\N	77	f	d59b66f5-6dc0-456a-a47a-6a7b0d0e820c	\N
1905067	\N	78	f	21947b41-fb66-440d-9d69-243bd204eba8	\N
1905067	\N	78	f	6a50e6ff-ddc9-4f7b-9e47-fac54420bce9	\N
1905067	\N	78	f	46211066-ac22-4ec1-bd8d-c89e292bf5bb	\N
1905067	\N	78	f	3e897050-319c-4fb4-abb2-acff3d0b5aa5	\N
1905067	\N	78	f	4ed22f58-04ec-461f-9bcb-86dd0e71c222	\N
1905067	\N	78	f	5f56a97a-a5f7-46b3-b155-61a97c9f2a37	\N
1905067	\N	78	f	4ae95014-dba0-45b8-807a-fd53faf550fb	\N
1905067	\N	78	f	33b052ec-b480-4061-b07f-e05aeee5df54	\N
1905067	\N	78	f	38a348e3-59b8-4db1-862e-a62782742969	\N
1905067	\N	78	f	b40dfc68-848f-43b5-8547-63795aac76f9	\N
1905067	\N	78	f	e64c992d-3d3b-4e00-9392-73b5be046d27	\N
1905067	\N	78	f	e815caf8-2cfd-4aeb-96bb-a6d7ca907d36	\N
1905067	\N	78	f	e8602343-c33c-4014-8f3e-9c70be799866	\N
1905067	\N	78	f	23f66417-4bfc-4a1f-9eac-07cae06dd1c4	\N
1905067	\N	78	f	8dcc1a28-ee46-4ace-9cdf-9720030cebad	\N
1905067	\N	78	f	edceede1-fe4d-4f3c-865e-8e6405ea3508	\N
1905067	\N	78	f	e04c5d0a-82ba-432d-93ef-ee5f86d64bf7	\N
1905067	\N	78	f	68b617fa-9ebf-4038-86fd-96e2d6fef960	\N
1905067	\N	78	f	0ee33270-97ad-47ab-8b67-e1613975446c	\N
1905067	\N	78	f	a41322c9-8332-412b-bd2e-280cb23c3c4f	\N
1905067	\N	78	f	99c1d42d-c0e6-4fb8-9032-dc18137098f8	\N
1905067	\N	78	f	25d1019f-d158-41d2-9299-2c9022a366ba	\N
1905067	\N	78	f	c97b3906-989d-4841-a912-f12e26b20816	\N
1905067	\N	78	f	b51b138d-692c-4ae7-925e-8dc4a963f113	\N
1905067	\N	78	f	d9320e5e-5145-4ff2-9dde-33e258c31ad4	\N
1905067	\N	78	f	8fd9c682-544d-4c9b-824c-382e99fb93c5	\N
1905067	\N	78	f	5612126c-a200-4b23-83b5-89c806d5e838	\N
1905067	\N	78	f	9d17772a-bc99-4b8f-ba42-3ec9d7ed184f	\N
1905067	\N	78	f	6353090b-d287-4732-9a7a-a3f6e7e2b143	\N
1905067	\N	78	f	1732866c-1001-4762-b18e-c8f69338daf1	\N
1905067	\N	78	f	19334a2a-1b3c-4b54-8064-cfc9874b3102	\N
1905067	\N	78	f	b3c15632-2662-4871-836f-6f5c429568d8	\N
1905067	\N	78	f	81f3eeb4-0991-4a28-aeca-e231ec5ffa9c	\N
1905067	\N	78	f	2dc0d0df-663d-407c-87c6-3be47eee64c7	\N
1905067	\N	78	f	2ae51882-7d5c-4a52-badd-265b40d5feb4	\N
1905067	\N	78	f	a7616770-5981-4874-9aec-24614e2f8586	\N
1905067	\N	78	f	d75936ba-a2c5-49f7-b502-fe3f261d558f	\N
1905067	\N	78	f	9abe0140-7cac-4be2-838a-0357376c4517	\N
1905067	\N	78	f	acf54bbb-d789-4d95-9361-71d5f82cd1e9	\N
1905067	\N	78	f	569ae434-dacd-426c-8c8d-2afa75def631	\N
1905067	\N	78	f	5cad7dff-4534-4d21-88b7-94c903ca1806	\N
1905067	\N	78	f	ac428db2-9f75-49af-abf2-3e0b5ba7f890	\N
1905067	\N	78	f	2df6d508-c582-4f23-bf47-c5bfb19af148	\N
1905067	\N	78	f	ff044485-141f-4422-bfdd-1bab9016524a	\N
1905067	\N	78	f	97d734ec-f986-4eb6-8788-51ddf7cfb1ee	\N
1905067	\N	78	f	f649e492-5f29-45d2-9e64-4111d5f8f07e	\N
1905067	\N	78	f	4874bd9b-3016-49dd-887d-8f77d244ec5b	\N
1905067	\N	78	f	24039231-6d93-4d5b-abf5-4db5c551bf4b	\N
1905067	\N	78	f	0f27382a-4205-4628-8270-c3e164619313	\N
1905067	\N	78	f	4e4ebc96-2574-4ef4-a340-36c475477477	\N
1905077	\N	83	f	92c277e5-2d81-4dc5-a40b-946be0bcfa78	\N
1905077	\N	83	f	de55da8c-994d-41d8-8676-4dfbabd49f9c	\N
1905077	\N	83	f	57b0fc52-3f49-4897-b4b2-0b5d240ba7f8	\N
1905077	\N	83	f	d7264e56-783a-48bb-b7a9-a1b45878b147	\N
1905077	\N	83	f	0d64be88-7304-4759-aeeb-5356bf71ea79	\N
1905077	\N	83	f	ee786829-91f4-4fe9-afea-bf796f40b4ab	\N
1905077	\N	83	f	7eca86bb-5f23-4c82-b0ea-f3659e221c15	\N
1905077	\N	83	f	7d883360-2ef9-42a6-94b5-96e47ee7ad38	\N
1905077	\N	83	f	dfb79c9a-a555-4e52-966e-93bb1ed44c28	\N
1905077	\N	83	f	a305d5c3-6df3-4d5f-be7c-8552468bd621	\N
1905077	\N	83	f	5b779ffb-acb8-4787-949a-08ba1edf40ba	\N
1905077	\N	83	f	33b2c471-d2ea-4aab-984f-fbba97964de8	\N
1905077	\N	83	f	b33e2a0d-bbf0-4bb0-8a8e-5e982e68ec2f	\N
1905077	\N	83	f	ef74b6dc-91f1-4f04-b1f0-275eff14ffe2	\N
1905077	\N	83	f	a6549d6f-0692-4ac2-aa2f-f9fe9084ce54	\N
1905077	\N	83	f	8351cd1f-9eb9-4625-a5de-b4651bf099b2	\N
1905077	\N	83	f	9f6b2995-5270-4bc8-b6ae-0fa3aaa25ce5	\N
1905077	\N	83	f	eba98f70-760e-4f63-b3d9-60230ea1aeb3	\N
1905077	\N	83	f	b949454f-c66b-4da0-9503-815e9a986a71	\N
1905077	\N	83	f	6dc14d81-2ae5-496e-a8cf-2d668e453734	\N
1905077	\N	83	f	0211d94d-7d18-453a-9a45-de882f01276d	\N
1905077	\N	83	f	98ea501a-5414-4834-bfc5-bff670446ed6	\N
1905077	\N	83	f	1afdb8a9-6e7b-4a9e-90a4-f729668be20b	\N
1905077	\N	83	f	28a68cc1-f628-423d-a5c6-b537bbac2e21	\N
1905077	\N	83	f	a99aafef-fbd5-4fe8-9220-e35278f3b25c	\N
1905077	\N	83	f	a771bad6-314c-4a4c-8c82-5e1a31b835cc	\N
1905077	\N	83	f	1dde1bdc-144c-4ac8-aa64-e809f80792a7	\N
1905077	\N	83	f	93703fa7-fe35-49f1-8307-b0d31d41da8d	\N
1905077	\N	83	f	09ce15f6-dc6f-4d0b-9fd8-92a454989422	\N
1905077	\N	83	f	f74ec059-e6a1-44c0-b36b-dae7ac97c414	\N
1905077	\N	83	f	8fbc2f25-50ad-4180-b297-9de12da8d7b4	\N
1905077	\N	83	f	c32b4a28-9c49-43f9-a07d-f21c041185f2	\N
1905077	\N	83	f	91229cb9-25f4-45c9-9396-07d0bfd5a98d	\N
1905077	\N	83	f	36acc39e-7632-4c27-86e3-4797bfc67b18	\N
1905077	\N	83	f	7cd4d166-8813-4259-9639-71fb78ae61d8	\N
1905077	\N	83	f	4751795e-7a61-413c-b5bf-b1631a7b0975	\N
1905077	\N	83	f	b83b5b16-7882-4e5e-a314-98ae5f43cefb	\N
1905077	\N	83	f	b49dbe8e-a6f9-4fcb-a43c-c965027f1655	\N
1905077	\N	83	f	67807007-a483-4e39-9825-ee4f3132e2c6	\N
1905077	\N	83	f	9fc52455-22ae-4476-a3cd-86c9a91e9306	\N
1905077	\N	83	f	90f31d14-31cf-427a-ab70-491bae7b4ca8	\N
1905077	\N	83	f	cb5f76a6-dabc-47ee-8768-c66f3b73d8ff	\N
1905077	\N	83	f	64e5478c-3b73-4cb4-a266-dc4b3aca7458	\N
1905077	\N	83	f	5d9c5780-b7ad-4b84-9eff-12b0d6847116	\N
1905077	\N	83	f	aab09f43-aefd-41ea-af80-15653500837b	\N
1905077	\N	83	f	a3870fc5-1a97-4d88-8460-44f63ea13677	\N
1905077	\N	83	f	cdbcadd9-cbef-4e7c-a7c8-02b327e4573d	\N
1905077	\N	83	f	9e689843-a925-4d90-88ad-53776a9e44ee	\N
1905077	\N	83	f	eebef72b-00e3-495c-ad36-3bb9e64dfe52	\N
1905077	\N	83	f	c31aed4b-764c-4c8a-be8d-09c621028358	\N
1905058	\N	86	f	0dab5793-6bb5-4ef9-8aac-e22f5a5f47da	\N
1905058	\N	86	f	b666afd4-e552-4fcd-90dd-359202a2b3ae	\N
1905058	\N	86	f	059da9b7-0af0-4916-8b83-68229c2588a8	\N
1905058	\N	86	f	9f38c2a5-a428-48df-ba4d-fcfa9bec2e21	\N
1905058	\N	86	f	d82dc884-d97e-49a5-8273-3bea9f834ed1	\N
1905058	\N	86	f	f41e92b6-cf8a-4309-b361-a362df7d71a5	\N
1905058	\N	86	f	584d7545-4b41-465e-af69-ec06e5692ecb	\N
1905058	\N	86	f	d40d14ee-a658-4927-be8b-dae133776f14	\N
1905058	\N	86	f	67a1653d-ac47-45d9-bc70-0c6c331e46f0	\N
1905058	\N	86	f	23a0bae3-7d15-4982-b560-b894f4a53edd	\N
1905058	\N	86	f	39e7d531-d112-4e97-b810-abe23dbd07b4	\N
1905058	\N	86	f	1d5ef2d3-fff2-4103-8c55-521d99066e7d	\N
1905058	\N	86	f	67597336-b335-48f9-bc54-52ffb704a08c	\N
1905058	\N	86	f	7f9e1b0e-044f-424b-90f3-582c21477258	\N
1905058	\N	86	f	37e5c87a-d5a6-459c-bd01-4ad284995f54	\N
1905058	\N	86	f	8665064e-616a-4ee5-8f6d-bb1ca2540b76	\N
1905058	\N	86	f	64e04fa7-9651-4960-9c51-673099547e3e	\N
1905058	\N	86	f	f7241f1d-897c-4220-aafb-ae32d5b3ad7e	\N
1905058	\N	86	f	98766588-dafe-4620-a5a2-dbcf160191f5	\N
1905058	\N	86	f	c0491204-b1f1-4784-8bbe-5f39b2d0038d	\N
1905058	\N	86	f	db7c6524-c0c5-4ed3-b563-57f63c6b8a7f	\N
1905058	\N	86	f	338193e2-715f-4af1-bac1-fe2e5a7810d8	\N
1905058	\N	86	f	101a3314-09a7-481f-acbb-a5df652093a2	\N
1905058	\N	86	f	536461c3-7e0d-4ec8-bbbe-b71c9f0843dd	\N
1905058	\N	86	f	e72013c4-54fc-4ee5-a709-250d349d3787	\N
1905058	\N	86	f	16a97165-1fd0-40ac-9f80-b179ea8a29fc	\N
1905058	\N	86	f	ce7bd3fd-0994-4a17-8544-0c6b8065d37d	\N
1905058	\N	86	f	fdc817be-3fe3-431b-a57d-dd21ef16f61d	\N
1905058	\N	86	f	e5ec33a6-19b7-48ed-8788-09f2468ecd3c	\N
1905058	\N	86	f	ed5d841d-b392-4ac4-930d-4e0e1cdef961	\N
1905058	\N	86	f	1db3c0bb-9931-4021-aaff-728e4ea2815a	\N
1905058	\N	86	f	0ce77208-aafd-434f-8f34-2c6c4de28c5c	\N
1905058	\N	86	f	1ab398a7-e691-4624-98c2-8d93f3445be6	\N
1905058	\N	86	f	86e7d31c-db1b-4ba4-a946-a179b8113c66	\N
1905058	\N	86	f	3fb37a04-340c-4008-87da-a3ecc8dc5091	\N
1905058	\N	86	f	2b5fd1b1-7011-4ce2-9ccd-2a4e0a0df312	\N
1905058	\N	86	f	95ee0404-d203-4da2-ae7c-82850c21314c	\N
1905058	\N	86	f	59ac2d0f-4050-49b1-aef0-9548e59cbd21	\N
1905058	\N	86	f	97beb5b0-a147-4ca9-9c62-8998344a38c6	\N
1905058	\N	86	f	993e7eb1-9c40-4d3f-81a6-a66059331d03	\N
1905058	\N	86	f	9b63899b-a1a9-44d8-a32b-fe318dcde8f8	\N
1905058	\N	86	f	2f904422-074c-419b-b273-8d44e57ce9b8	\N
1905058	\N	86	f	2bd92790-d77f-494a-841a-b13b523c9ae8	\N
1905058	\N	86	f	ffe2f763-3ee2-47cf-a960-51db07d4864b	\N
1905058	\N	86	f	3ae59c04-2776-4aa6-bf28-d879c760769d	\N
1905058	\N	86	f	fcffdb83-9c96-4528-b9f1-283df2a338f9	\N
1905058	\N	86	f	b29004e1-390e-489e-af0d-6c952325c408	\N
1905058	3667	86	t	24f1b014-e85d-4bdd-be7a-5772d687f742	rahmatullah
1905058	3762	86	t	cbc86ca0-63b9-43c6-bb4b-dc47f533d706	nizam88
1905058	3762	86	t	07738ab5-8074-4252-956b-b8a59031736b	nizam88
1905077	4124	72	t	be6e14d3-fd0f-4630-b4bd-a0059d367e0b	nizam88
1905088	\N	79	f	91182046-0b33-4a95-9c81-c8ee811de0cd	\N
1905088	\N	79	f	eb3593c7-94c8-4683-a4c8-5c65cbbb098b	\N
1905088	\N	79	f	b5576aa4-1e44-4a69-86df-e4e2fc6bd75d	\N
1905088	\N	79	f	0f798ab9-1b2a-469c-9f1f-3941958f9254	\N
1905088	\N	79	f	a5201e24-db0a-438f-8a1b-9f9482f930e0	\N
1905088	\N	79	f	32c57aa8-cd47-490d-ac8d-288e14ea3dd2	\N
1905088	\N	79	f	b51e141a-a6a2-4501-b848-217ff3bf875e	\N
1905088	\N	79	f	e068da80-0a17-4993-8457-2eb6eab467ff	\N
1905088	\N	79	f	7cc36abf-a216-4461-9d8a-e1fe0fc6a37a	\N
1905088	\N	79	f	45075f1c-b03b-4edd-bbe6-039f039cf220	\N
1905088	\N	79	f	c8a47215-a1af-4bae-bce5-b1959ab14813	\N
1905088	\N	79	f	da1e039c-06ae-4318-b825-b981e485239b	\N
1905088	\N	79	f	328b43ee-6446-4ca2-9f0d-2c537a3555d0	\N
1905088	\N	79	f	4aa6b8ae-8923-440c-b053-e3edf502e26c	\N
1905088	\N	79	f	8c1b64b4-a415-409b-817c-b53803bf0d5d	\N
1905088	\N	79	f	a9c490df-530a-48d0-9ad6-594029463c71	\N
1905088	\N	79	f	436d018d-962a-4f68-a702-31c6363318b9	\N
1905088	\N	79	f	b20884bf-9196-44db-bc47-c186d9288b74	\N
1905088	\N	79	f	f9b4e4cc-3475-4533-b89c-af29a26a976a	\N
1905088	\N	79	f	24602309-4d50-4acd-b39e-ed38919f46b4	\N
1905088	\N	79	f	ae983995-92ca-4074-97e3-269b9af772e6	\N
1905088	\N	79	f	bb6d54a3-f5dd-46fc-8125-1d3a7b0d0c2a	\N
1905088	\N	79	f	84ac6c02-0c0b-47dd-9119-d762671b5910	\N
1905088	\N	79	f	864066dd-b54a-4451-aeeb-d9322af7d335	\N
1905088	\N	79	f	d9562a6e-aebf-4d6a-b77f-c0c23aafe49b	\N
1905088	\N	79	f	a4868ed1-4b58-439f-85a1-35749db7912e	\N
1905088	\N	79	f	055857e3-692a-415a-914d-d4f42948edf1	\N
1905088	\N	79	f	630839aa-cfc5-45c7-885d-9fd7f68dfb05	\N
1905088	\N	79	f	6ba6504e-5820-4a78-8d6d-50bcdea928f0	\N
1905088	\N	79	f	08aa2eb1-b720-460a-ae91-48f1f5ccd9d4	\N
1905088	\N	79	f	dba25f8a-d8ed-4dc0-9ea3-e9ad8b5cad82	\N
1905088	\N	79	f	0c8483b5-7ce7-4e9a-8521-879035910af5	\N
1905088	\N	79	f	f2f18258-b295-4a77-9ece-cd3de71085e1	\N
1905088	\N	79	f	4883ada7-5d1e-4a53-945c-cc127c570b74	\N
1905088	\N	79	f	2e30bf08-8aa0-4a9f-b0b5-71d2dc99acbc	\N
1905088	\N	79	f	5a94eaef-03b9-4d06-a500-da6d2f04e21f	\N
1905088	\N	79	f	3e5b4aed-190c-479b-9a68-d7ceebe453e6	\N
1905088	\N	79	f	da05980b-a764-401e-81b9-a9ddd22bad1b	\N
1905088	\N	79	f	f8605ddb-3f19-4e8b-b540-bc1120e918dd	\N
1905088	\N	79	f	61f5199b-cf5f-417d-b4e7-a5bca512eafa	\N
1905088	\N	79	f	53f37354-9739-464c-a4ac-b79dc1b32161	\N
1905088	\N	79	f	63ba1b49-04e5-42e5-810a-a573996fb2f0	\N
1905088	\N	79	f	1aefee91-e3c4-41dd-8f36-d45d9042ba48	\N
1905088	\N	79	f	52af2455-f9db-4f85-bd58-1bba2d4b7a40	\N
1905088	\N	79	f	5fd754f1-6a99-4987-9eb2-f40f811ea3ca	\N
1905088	\N	79	f	27da1b65-97ea-4f1c-ae4b-00c7ca671d17	\N
1905088	\N	79	f	ac80c8f5-0f6a-4060-9630-58a7724c1a24	\N
1905088	\N	79	f	dd7c0feb-0610-4012-9006-c37b0700a4d5	\N
1905088	\N	79	f	68c3c836-2a3e-4cb2-abf6-2927e7449285	\N
1905088	\N	79	f	ee1b369b-f209-4551-97b9-0a4059e58169	\N
1905088	\N	80	f	dbe373f7-d7e6-4436-a4d9-98ece71cf026	\N
1905088	\N	80	f	f22af911-965b-47af-b079-be0c32cccf62	\N
1905088	\N	80	f	8db18935-7c6c-4593-b84e-27b1303035d1	\N
1905088	\N	80	f	ff492a21-e9ad-47b1-8a62-d776c6c2a499	\N
1905088	\N	80	f	fcdd434f-b823-4bc3-8af8-18ec901ae865	\N
1905088	\N	80	f	ab3c520e-009d-4389-a7f6-dbeb741e9429	\N
1905088	\N	80	f	c9d0dfc1-7823-4c64-af7a-98327ccd45de	\N
1905088	\N	80	f	f5801673-938e-4f01-97b3-102cf4f6fc17	\N
1905088	\N	80	f	6fd31a48-8b73-464a-b4ce-66d126d0c319	\N
1905088	\N	80	f	c340fc8f-1dd4-41fc-8bca-f2f6802820d2	\N
1905088	\N	80	f	40141e39-4624-49bc-b0b5-4ddb4b369ba5	\N
1905088	\N	80	f	5669cdfb-e098-4b0f-bb07-85fd7e136c43	\N
1905088	\N	80	f	6903a87b-c672-47b4-b726-8f8e3dfc19cd	\N
1905088	\N	80	f	f0694f47-571c-44c6-a7b2-c86d022b6dc0	\N
1905088	\N	80	f	5e25b033-40e7-410a-8702-a76de6e2a476	\N
1905088	\N	80	f	4b077a6b-4855-41ee-840c-814124185eec	\N
1905088	\N	80	f	d9a1e0f6-a97f-44e2-931d-4f56e31c6b54	\N
1905088	\N	80	f	954aa5ab-7e08-4675-9a0f-b96502da4aa6	\N
1905088	\N	80	f	950e238a-e9e8-4bc1-ad98-da2fee3f698d	\N
1905088	\N	80	f	55e33401-97a1-4f9d-a82f-0946aa29c3b4	\N
1905088	\N	80	f	6539675c-1205-4023-b2e8-428da586e2ee	\N
1905088	\N	80	f	c766c9aa-93e8-48d2-b7f4-50f0fb822549	\N
1905088	\N	80	f	779d8ad8-09c7-485b-82e3-52ad8af7e2f6	\N
1905088	\N	80	f	ceab15d8-0e51-42da-80c8-184c76de032b	\N
1905088	\N	80	f	4c65ed32-1f51-4306-b50b-c7260826e963	\N
1905088	\N	80	f	edeb1e4b-d7f9-46ae-aa7e-e2569e147db1	\N
1905088	\N	80	f	1d5b9919-75c4-4c8f-8479-82fb76b548ec	\N
1905088	\N	80	f	f216c6c0-9946-4d26-99a7-8d72b1c6e8b2	\N
1905088	\N	80	f	261e2684-03f3-4017-8e44-3b145714bd91	\N
1905088	\N	80	f	8ddd0386-3ee3-4c85-a2c3-db4e6b5eb42b	\N
1905088	\N	80	f	e9d09a22-9a3c-4b34-af23-a8ffb4a4afc7	\N
1905088	\N	80	f	7b46c91c-e206-4272-8d37-2c68e2a9cfa8	\N
1905088	\N	80	f	a1d76eb1-0b25-4e05-9af1-f494cd56b2cd	\N
1905088	\N	80	f	57562f05-2a86-4bfc-bbd2-2c068a1ca841	\N
1905088	\N	80	f	324d6e9c-37a8-42ba-8ddf-f9ff35d30f59	\N
1905088	\N	80	f	57cfba89-0875-4ef4-aaff-243129b97360	\N
1905088	\N	80	f	684deb4e-6903-46eb-a387-c043bf8b5980	\N
1905088	\N	80	f	e931a92d-569a-428e-a9cd-009c5244d4a5	\N
1905088	\N	80	f	c71511a3-06d5-4bb8-8840-3e3541daaf6f	\N
1905088	\N	80	f	33cd1086-ebd4-4fa4-a71f-e339da03f535	\N
1905088	\N	80	f	15c3e80b-e5e0-43ad-8329-48936d987303	\N
1905088	\N	80	f	a0af14f7-f06c-463e-818d-087092eccc08	\N
1905088	\N	80	f	4469c5d4-7a85-4c91-aad5-5bcd23bc34df	\N
1905088	\N	80	f	f9effebd-0499-4510-9c10-25e008969aa4	\N
1905088	\N	80	f	6073c8ac-2646-4fd5-b520-da405d160450	\N
1905088	\N	80	f	f5a7f008-7611-4436-a999-889b8092e155	\N
1905088	\N	80	f	a1b5a68a-e744-44f2-82a8-8806a628044a	\N
1905088	\N	80	f	c0835ab7-3d26-4a24-96fe-05b2859de965	\N
1905088	\N	80	f	8bdfa6fe-e907-4793-a247-680bcf9680e3	\N
1905088	\N	80	f	28f4f33f-2e4a-46b1-b1dd-d354f3871775	\N
1905008	\N	81	f	4753615a-ee7a-4f3a-9d1a-abe414af2757	\N
1905008	\N	81	f	021ea723-d449-4ce2-b3f7-584cffcc83ba	\N
1905008	\N	81	f	76accc1e-0194-4f87-b5b8-3b39354df919	\N
1905008	\N	81	f	bd45dd50-752a-4b32-a505-c781c9c30cf3	\N
1905008	\N	81	f	9ced1d62-6c0a-440c-afbe-ad8e882d1701	\N
1905008	\N	81	f	0f13b236-7ce7-445a-b65c-6a354065fbf3	\N
1905008	\N	81	f	4b2307be-c305-4d57-a0cf-644c74dd9d98	\N
1905008	\N	81	f	105a2db4-6a87-401e-92e3-785c4ebe7fcf	\N
1905008	\N	81	f	45c5cf9c-5f00-4168-a5a1-1c40c83030e5	\N
1905008	\N	81	f	5ad0ea66-3df4-4d99-93b1-711f5f1d7e03	\N
1905008	\N	81	f	9db8bf5e-23c0-40d7-b950-9a70a93c7400	\N
1905008	\N	81	f	3307524e-0d6d-42e7-9ed7-c00257164152	\N
1905008	\N	81	f	319d178b-1f2d-4a67-b1d7-f2a703f4fd09	\N
1905008	\N	81	f	e8c478b6-c051-4465-ad91-f1785ef89f4a	\N
1905008	\N	81	f	856d01e2-daee-49e7-a7eb-36d6fa824797	\N
1905008	\N	81	f	a37b5cfb-c633-49c8-828b-5d5558827057	\N
1905008	\N	81	f	efccc4c9-935d-40d9-9e60-e5035a07f8b1	\N
1905008	\N	81	f	9f65b344-7732-4324-8736-1019c588ddf6	\N
1905008	\N	81	f	9aad16d9-36ab-475e-b7a7-16a3f02f0f18	\N
1905008	\N	81	f	fa337c52-aa8a-4afe-8b9b-52ddbc424815	\N
1905008	\N	81	f	28884b06-8e86-435e-89d7-23541862a9da	\N
1905008	\N	81	f	aaa74bdc-4211-4f85-b7aa-01bffeec8c7f	\N
1905008	\N	81	f	a35573b6-1a70-49a1-9c33-40193d4ce889	\N
1905008	\N	81	f	584dbd7f-ec45-4328-84e1-fb1a84067f1b	\N
1905008	\N	81	f	63a34a96-5789-411e-bf6a-d2a211fdbccd	\N
1905008	\N	81	f	f6848a22-f35d-49eb-8371-8cd7ca5e7f73	\N
1905008	\N	81	f	fa672c63-09ff-48c8-b7e5-506d78ecd0c7	\N
1905008	\N	81	f	5cfdeae1-88c8-4571-bebf-3efc46de6164	\N
1905008	\N	81	f	93995fee-ed0e-445e-a63c-b90e7d9b3ff4	\N
1905008	\N	81	f	30d626e0-8af3-45af-9050-b5aee08410c8	\N
1905008	\N	81	f	d4459f97-3c94-452e-b817-ef6d36799fc9	\N
1905008	\N	81	f	9ac9c6ff-b60b-4c41-9684-82047108bd8a	\N
1905008	\N	81	f	af2c3454-9a51-4175-b15e-d883dd876350	\N
1905008	\N	81	f	9b74231e-d162-4d0f-831a-a1ee8621eedd	\N
1905008	\N	81	f	1da6bc50-f97c-40aa-b22d-91c3c2e56241	\N
1905008	\N	81	f	f7f17ddf-7012-4723-a023-e949756afc38	\N
1905008	\N	81	f	81552d99-e70c-4630-923e-6a132945fc0b	\N
1905008	\N	81	f	7c98f565-c8ea-408c-b4b0-a94f26326dd1	\N
1905008	\N	81	f	67a86643-fecd-476f-9795-17c17ac16e48	\N
1905008	\N	81	f	11c74102-defa-4edd-a1f4-a898e734a006	\N
1905008	\N	81	f	a86dd13e-273d-48fc-96f9-34d9a5cc21ad	\N
1905008	\N	81	f	fa0ba24e-0dfd-4e02-93c6-282662795b4a	\N
1905008	\N	81	f	cf44b948-4ed3-43e3-9f75-0d466edf5156	\N
1905008	\N	81	f	bf4b256a-2662-4fa7-8be4-8e9ac4099ed2	\N
1905008	\N	81	f	864a723a-c5e1-4c36-875e-da4f4734a4aa	\N
1905008	\N	81	f	1d9a1b6c-4f0a-40f2-a96e-e36e29217757	\N
1905008	\N	81	f	8a80c928-7cfe-40ed-af66-6d54fd1311a8	\N
1905008	\N	81	f	4d10d95a-2ca6-4e03-bed8-273dc560f322	\N
1905008	\N	81	f	ad12d45e-3a39-4506-87fc-7c3630d19e47	\N
1905008	\N	81	f	82d3319c-a519-44ee-8ae6-559535a916cf	\N
1905008	\N	81	f	dd9ca465-bbe8-4bd0-9f58-dd5d607277ac	\N
1905008	\N	81	f	7be7ac20-216c-4cbf-9664-7232cf695c0e	\N
1905008	\N	81	f	a3bcfe0b-3365-4606-b015-7ed913d95565	\N
1905008	\N	81	f	1b436b15-af1f-4506-b226-42b5501e5244	\N
1905008	\N	81	f	9f98e4cb-fcc4-4fec-a19e-5bc32c503413	\N
1905008	\N	81	f	d117c813-0d31-468c-9bae-183d5bc05cab	\N
1905008	\N	81	f	a32105a0-4f64-4bf5-8c63-508c6779d14d	\N
1905008	\N	81	f	f75ecbe5-2d7e-47f8-8e83-89c82868d228	\N
1905008	\N	81	f	07b6f5fb-ca5d-4d4c-a37b-6e04ce1a7e63	\N
1905008	\N	81	f	893abce0-e011-41a8-9dde-6f58cdcb4804	\N
1905008	\N	81	f	b5bd35a7-f1c3-4556-9246-12d99b542435	\N
1905008	\N	81	f	2dfc2121-2384-4249-b2b2-4fe41f85fc4e	\N
1905008	\N	81	f	b90a330a-c088-4a78-8c58-e0716950e886	\N
1905008	\N	81	f	1a968087-8e30-407f-a50a-c5570b17348f	\N
1905008	\N	81	f	479ada1d-0ba5-4e6a-80b3-4882a8e634d4	\N
1905008	\N	81	f	9d450f2a-1da9-4007-b229-a245ececeea1	\N
1905008	\N	81	f	e1f2679f-49d9-4165-972c-11ee77fc1cbc	\N
1905008	\N	81	f	066cb8aa-35a6-4db1-89c1-ed4c808e18a1	\N
1905008	\N	81	f	74327b90-a0ca-4881-8733-a48370655207	\N
1905008	\N	81	f	8347622c-adf0-4448-b963-5ffdd5cab229	\N
1905008	\N	81	f	d53c4d92-5ef3-4ef0-8981-675973f709cb	\N
1905008	\N	81	f	a16df02d-05cc-4975-8b4b-69ca768b4ade	\N
1905008	\N	81	f	b198987c-fb41-42f8-9e19-1232f2e54bdc	\N
1905008	\N	81	f	fd6a49c0-46ea-4373-bc3c-3bc752dd3e42	\N
1905008	\N	81	f	26db8df0-90e0-4632-b1d6-c9529b271ed9	\N
1905008	\N	81	f	fb54d3f6-cd05-454a-965f-4982ab8b16e6	\N
1905008	\N	81	f	f7380e2f-3b17-43af-bcf7-3d798a05280e	\N
1905008	\N	81	f	161f38fa-3496-470a-a301-ee3b36025194	\N
1905008	\N	81	f	5ce23bfb-c5c0-41c4-a239-501ec37960cd	\N
1905008	\N	81	f	91dbb967-d1eb-46ae-9d19-87686218f4e7	\N
1905008	\N	81	f	c1d008f6-1a28-4c8e-941c-81d55505b4aa	\N
1905008	\N	81	f	a89eb358-9cc9-4b8f-9921-fb9ec70b5561	\N
1905008	\N	81	f	b869ee05-fafb-4267-99f7-06f7083adcc8	\N
1905008	\N	81	f	88acbaa7-1bb9-4226-bdff-3ad4c75be5f3	\N
1905008	\N	81	f	ad9cc0ce-a32a-4823-a1c0-2f0c47bde552	\N
1905008	\N	81	f	5ff7b7bb-1a32-4b42-b95f-f50a803e9559	\N
1905008	\N	81	f	d088d873-4783-44a7-9e0b-9cdcc78faa6a	\N
1905008	\N	81	f	f7ab28e5-0dc3-41df-90f4-d9aebb545b87	\N
1905008	\N	81	f	9410ca9f-0dbb-4733-a759-85dee8ee26b3	\N
1905008	\N	81	f	56c16c5a-1e70-4408-b61c-bdbbd3a979f4	\N
1905008	\N	81	f	258a8442-83f9-49fe-9970-09ec34c4f5a4	\N
1905008	\N	81	f	a721fac8-8998-4fb3-8ba5-8bfd5d533e37	\N
1905008	\N	81	f	90545244-195a-4784-bd39-ca6c037d2125	\N
1905008	\N	81	f	583565d3-02d3-433b-bf81-327e124341bb	\N
1905008	\N	81	f	fbcbd8ca-f297-4a40-893f-cd9575420784	\N
1905008	\N	81	f	485bb09d-0872-49aa-8f81-3c4b338297cf	\N
1905008	\N	81	f	31b5df6d-74c1-422a-a3a4-719258dfd5bf	\N
1905008	\N	81	f	2c62238e-cdca-488e-b64b-fc9e0868c59e	\N
1905008	\N	81	f	ca27756a-2caf-4776-9610-e608a60692e4	\N
1905008	\N	81	f	2662854c-c2de-4b92-8e15-38aede9b0b76	\N
1905008	\N	82	f	8329fb39-3a62-41b5-a881-a84a49712cef	\N
1905008	\N	82	f	b7241ebf-424f-4132-9bd8-32b4b9c0a885	\N
1905008	\N	82	f	cc55d363-659c-4dc2-b20a-74beed882734	\N
1905008	\N	82	f	e85c4dc1-2bc1-4d2c-aa83-bf6facdd3f36	\N
1905008	\N	82	f	e1bea217-2dac-4783-bf41-6bd2997879f8	\N
1905008	\N	82	f	fe8d1bec-231a-4cb4-9c45-56facf805e30	\N
1905008	\N	82	f	0a44efb9-2c57-4915-acce-a23653b01a41	\N
1905008	\N	82	f	47ec853c-914b-4935-8f6c-9fa46ecbf434	\N
1905008	\N	82	f	acefcdaa-585c-4b87-aa7e-1dfede5701ee	\N
1905008	\N	82	f	635e8147-baa0-4e2c-9c14-9584d8d25ebe	\N
1905008	\N	82	f	aa1dccb2-66a4-4ead-aaf9-46bfb6371a9a	\N
1905008	\N	82	f	3749d133-a791-4226-8d8f-7c7dce29d01f	\N
1905008	\N	82	f	389dd9af-92fe-4fcc-8bdc-9866a43c0b06	\N
1905008	\N	82	f	320c028d-9cf6-49e7-99d1-8aa1752e91b5	\N
1905008	\N	82	f	04a04a05-fd6b-4890-9cee-49c5af335f38	\N
1905008	\N	82	f	e7e96c55-1fe3-4359-a27b-dc227a48ff85	\N
1905008	\N	82	f	38feccf8-ec21-4ba4-a9fb-3d8bea5983d1	\N
1905008	\N	82	f	9f0a2951-4a74-45f3-94d2-e0877fdf1e3e	\N
1905008	\N	82	f	19277416-295c-4a9d-897d-9c403ab66f48	\N
1905008	\N	82	f	51e16f90-ea68-4be3-90bd-c62208362566	\N
1905008	\N	82	f	fe6423bc-f3a0-4cdb-a218-0a3c6410716f	\N
1905008	\N	82	f	b4de5765-38b6-4ce3-94ad-50543ad06cfe	\N
1905008	\N	82	f	ddf8af1a-65ae-4cc2-a3bc-430ac71d01d3	\N
1905008	\N	82	f	e76b8c79-1c95-4868-917e-156d5f02bcfb	\N
1905008	\N	82	f	c382badb-a60a-4c37-9cd8-ceccae97f8cf	\N
1905008	\N	82	f	00666e10-f224-42b1-979c-437cd67adab8	\N
1905008	\N	82	f	e4d4e9c7-a8eb-4e76-a27e-12a689d84dba	\N
1905008	\N	82	f	98cfa274-c688-4865-87a0-111ecf85db9b	\N
1905008	\N	82	f	5163b074-e108-4df5-9514-f7a1c726a4ee	\N
1905008	\N	82	f	ec0d427b-d387-4043-b668-9f8c232b05e5	\N
1905008	\N	82	f	8c7b6c7c-8420-4e86-b15f-0efa296414a1	\N
1905008	\N	82	f	ae97e74e-e966-4fe5-ae0e-83e0b5289add	\N
1905008	\N	82	f	fb9565e4-aad9-464d-a9a0-87db9e038aed	\N
1905008	\N	82	f	51496bc5-078b-42b3-ace3-2e231d63c581	\N
1905008	\N	82	f	9de5ecac-fe95-4edf-b279-29489e63a1d2	\N
1905008	\N	82	f	e7a094fa-9090-4011-8ff0-98825a871d8e	\N
1905008	\N	82	f	1b98b04f-9ba8-4206-b93d-921aa558f8c7	\N
1905008	\N	82	f	437dd015-e17c-41b1-a679-18799899f932	\N
1905008	\N	82	f	f51486b4-bf27-44b7-b654-4c31ff0292e1	\N
1905008	\N	82	f	97c0caa3-7131-42d9-be73-45af59001366	\N
1905008	\N	82	f	c91b07d4-0310-4214-8085-09ce5e2ce7cb	\N
1905008	\N	82	f	f5932eb5-fec6-43b6-b78a-fd9a1d194884	\N
1905008	\N	82	f	02c185b5-c076-4126-b27a-c0838aa44c25	\N
1905008	\N	82	f	094699ff-6844-4913-b6c9-7123dca39cdd	\N
1905008	\N	82	f	78445e60-3e87-4a78-8e45-336b530fa9a0	\N
1905008	\N	82	f	2e2f36b5-4939-4ea2-86a6-3394759885f5	\N
1905008	\N	82	f	51e58033-8f7d-4658-b07f-4ffa421fa395	\N
1905008	\N	82	f	8e3ebb5c-3829-4246-bf71-2ea80191ccc4	\N
1905008	\N	82	f	b6d5cd0a-2ab8-4344-aae9-ebada8d01fce	\N
1905008	\N	82	f	230185b4-eef3-4936-948b-b50d67acac53	\N
1905058	\N	84	f	98d1f646-fc60-4810-afdf-33bc1dc84aa7	\N
1905058	\N	84	f	be45b5ba-0bdd-4714-b0e7-d8eba24c0336	\N
1905058	\N	84	f	f734c61a-ec11-4d53-8f29-ef58166ac784	\N
1905058	\N	84	f	19443974-f07f-48b1-b9bb-c45420a2c311	\N
1905058	\N	84	f	77e05151-e9ae-4570-8973-f808870cea9b	\N
1905058	\N	84	f	fdd8bbc5-14b6-4ce4-97b0-aa11091a5255	\N
1905058	\N	84	f	b9ebc894-2faa-4096-ac65-89ccbe006d04	\N
1905058	\N	84	f	f88d1ef1-df74-4785-a869-2eb85d7edd4e	\N
1905058	\N	84	f	26a69dae-fd44-4c56-b8a7-9c1aa8e07dd5	\N
1905058	\N	84	f	3cf38054-6520-4f1a-ade2-86ba2ce55968	\N
1905058	\N	84	f	5974aff3-9845-4f74-8c87-2d1404ca0dd4	\N
1905058	\N	84	f	856d1d69-df0b-45d9-a477-1a7b023757b9	\N
1905058	\N	84	f	e68e0e01-c1d4-409e-8e42-36772c1e8a78	\N
1905058	\N	84	f	1aa09de7-154b-48e4-a7a9-0578573353c3	\N
1905058	\N	84	f	0fadc42d-1252-42f2-9f67-5cb0ae00a0ee	\N
1905058	\N	84	f	98ef7807-a1ff-493e-b661-b5f62c7c2eb5	\N
1905058	\N	84	f	87f070a0-cea5-442c-bee5-a2875fd144fd	\N
1905058	\N	84	f	2e33f696-7888-411b-8307-de964a7dc2d7	\N
1905058	\N	84	f	f61d6fc2-e726-4f4f-a03c-df939a546de5	\N
1905058	\N	84	f	321bbc59-f486-4df7-a9db-86930bce3f94	\N
1905058	\N	84	f	4133a9e0-5421-4175-8a43-cd36c17d6eee	\N
1905058	\N	84	f	0923a55b-77c5-4a35-a07a-251134dae4c2	\N
1905058	\N	84	f	e8bd0b56-d2f4-4a81-8a45-ded42e7f080b	\N
1905058	\N	84	f	e28a5a70-d52b-4a90-a6f5-35a45e4aa7cd	\N
1905058	\N	84	f	5e235511-9198-4faf-a2f1-c925848b39cf	\N
1905058	\N	84	f	3892a46d-9121-4882-ba78-5123d22f7344	\N
1905058	\N	84	f	604c090d-5fae-48f9-a935-33523cb7fb19	\N
1905058	\N	84	f	b17f8104-5b82-4d52-86b8-133ba36b0625	\N
1905058	\N	84	f	1c15cc87-6f3a-4b28-b20d-2cb1324a5072	\N
1905058	\N	84	f	85d7a7d7-5ca2-4085-bf3b-f3cd671baaaf	\N
1905058	\N	84	f	dcdedd75-bec6-4751-b2a8-842479dbc025	\N
1905058	\N	84	f	870fd706-4cd3-4b1a-a4a3-be70f9c2a905	\N
1905058	\N	84	f	eacc0af4-7b81-4336-99e1-f7e99e4baea7	\N
1905058	\N	84	f	1dade903-4b65-461c-8ee7-4d8b088de9a0	\N
1905058	\N	84	f	6b8e1312-1448-4a43-a04e-691860b0df6b	\N
1905058	\N	84	f	d6874621-ec84-4e9b-9fe6-38e6a29ef333	\N
1905058	\N	84	f	b5d70f9b-7114-4100-8ed5-13e5f6bb5a46	\N
1905058	\N	84	f	a97d9d2a-e113-40a1-a009-4985fb71b9a3	\N
1905058	\N	84	f	597d3a17-6b2f-4f2c-8327-b904a7806ed7	\N
1905058	\N	84	f	eb136ba2-8fee-4009-acc9-a6b1e64201e2	\N
1905058	\N	84	f	0d3dc783-8967-4d93-b397-5ba581e042ef	\N
1905058	\N	84	f	76c592a4-e7e7-48a0-9a9c-53280dda562c	\N
1905058	\N	84	f	8fa3a772-90c3-4442-9e93-e577f6d99def	\N
1905058	\N	84	f	64cfe352-f10c-44ca-a278-5c76a93927e7	\N
1905058	\N	84	f	d62b40d8-22ca-4958-be69-3dfe6bc3c832	\N
1905058	\N	84	f	572e1aa3-6692-42fd-a5dd-9183079482f2	\N
1905058	\N	84	f	135f2315-57f4-412c-892b-0a621489703f	\N
1905058	\N	84	f	a2a8ad37-0912-48f6-8691-d578581d584a	\N
1905058	3714	84	t	df3eb660-94bf-437d-9d94-fb75ee2b6e16	nizam88
1905058	\N	85	f	4d79fa99-612c-4fcc-99fa-e1d247218290	\N
1905058	\N	85	f	d3ba17c4-c302-4817-b0a8-1f37b8ab4b8b	\N
1905058	\N	85	f	5941797b-2c98-49c8-aea7-da1968c1a02f	\N
1905058	\N	85	f	8d015bfa-4132-4e7a-9fae-a6d3501a19b7	\N
1905058	\N	85	f	51e4f261-94d9-4e57-b6ca-6e402e23ccfc	\N
1905058	\N	85	f	046300c1-a220-4c96-88a7-1860070e55df	\N
1905058	\N	85	f	b31ea933-ba52-4856-bd62-dc5251ddebc1	\N
1905058	\N	85	f	d095059c-02b1-4eba-b46c-614f3691b760	\N
1905058	\N	85	f	59b3b117-22e0-4ab4-a033-cb52c8f7fe83	\N
1905058	\N	85	f	9f3d7bc5-70d7-46fb-8c5b-1ab6a4f89709	\N
1905058	\N	85	f	19ed3337-6e15-48e0-882f-1ccec68b6276	\N
1905058	\N	85	f	c7c47f29-e5f8-4b23-a2d0-6b331a6217bc	\N
1905058	\N	85	f	8d8cd0aa-f813-4b2f-9c81-48282338ecc0	\N
1905058	\N	85	f	710501c6-ff78-4a62-abc6-0ab8de40b81a	\N
1905058	\N	85	f	11704b2f-3193-4142-91fb-5b74634231bb	\N
1905058	\N	85	f	c65e90f3-d6a7-4ebb-a6ca-4ed3d29ab732	\N
1905058	\N	85	f	4d1ba1ae-dd4c-430a-b7e5-c5cfc97cd0a0	\N
1905058	\N	85	f	41eff07a-b4fb-49f2-9b05-96880b80890a	\N
1905058	\N	85	f	9006b3c5-9a1f-4e91-8b2a-f79e379508f0	\N
1905058	\N	85	f	ae41534e-8762-4c92-a4a9-f9f5db956b70	\N
1905058	\N	85	f	5fd64f65-32e4-49d2-8e00-5303af75811c	\N
1905058	\N	85	f	23ab3446-7edb-47ab-8ffd-7ed01f29ad8c	\N
1905058	\N	85	f	86f82db4-bd32-4b32-a68b-d05122768f02	\N
1905058	\N	85	f	5c4ff69b-605b-4ea2-8eda-0327ec89ac74	\N
1905058	\N	85	f	f605de0f-887f-4c70-98cd-8046676e953f	\N
1905058	\N	85	f	601bee92-d60f-42cd-b779-227d4015bd73	\N
1905058	\N	85	f	e687f74e-bfba-47ff-ad45-e52e1c6c59b4	\N
1905058	\N	85	f	0467535c-938c-4511-a011-b03df36402cc	\N
1905058	\N	85	f	3d2981cc-6f44-4893-a159-4754465598d8	\N
1905058	\N	85	f	06ca92b6-87c1-4883-b9d8-c0a587177e07	\N
1905058	\N	85	f	252cd7cc-c37e-4b5f-a0c6-9b45bb321552	\N
1905058	\N	85	f	045e0afe-0a56-414a-b6e7-b4d72d269528	\N
1905058	\N	85	f	58a63f76-ad26-4022-b479-90f0e526f52e	\N
1905058	\N	85	f	76d1032a-3fc7-42ae-863a-5f71a0b80a38	\N
1905058	\N	85	f	4ae832b3-3fbd-4b84-a241-f0e8a232bc86	\N
1905058	\N	85	f	e842c973-4801-4476-9155-bfc3f0273802	\N
1905058	\N	85	f	0930666a-10f6-40bb-ad8d-172a1a349dfa	\N
1905058	\N	85	f	ba19f171-a995-4183-8840-8916a500f723	\N
1905058	\N	85	f	5bd56d7e-8e35-40cf-8890-1cf1ab4798f9	\N
1905058	\N	85	f	7f1bbac4-4f78-4346-81fb-4253c06523f3	\N
1905058	\N	85	f	9c30d44e-eab0-4ea1-890a-b54c7fae79a3	\N
1905058	\N	85	f	00876906-b489-42a3-97e0-9316b261c2f2	\N
1905058	\N	85	f	b1204770-6b68-4072-829f-f02ed03a86fc	\N
1905058	\N	85	f	f524ed7a-1bb7-4433-8910-1010661f79d3	\N
1905058	\N	85	f	55376cb5-6172-4ae9-adba-72453369b2f7	\N
1905058	\N	85	f	ed0775c0-3bbc-4e5b-ab83-5e6d91b61a01	\N
1905058	\N	85	f	ebae6ab9-a235-4b90-a1f0-50f816ca0480	\N
1905058	\N	85	f	0e3363fd-b712-43d3-a605-995ac04626be	\N
1905058	\N	85	f	88856959-b161-47b3-83bf-c9f6618efcb2	\N
1905058	\N	85	f	94c6b79a-d9ea-433a-95b2-3386bb67e44b	\N
1905058	\N	85	f	9f345cb0-f795-4a08-a1f2-6c427cea4c95	\N
1905058	\N	85	f	14504d3a-6876-4772-a0ad-b47479b31ab1	\N
1905058	\N	85	f	462a60f5-6424-48d0-a8fd-182d2207bb82	\N
1905058	\N	85	f	2c1f2fc5-37da-4e6a-85f4-44d3b0f0c952	\N
1905058	\N	85	f	15d8f62a-5d1d-48fa-899b-5b278d2c9e9b	\N
1905058	\N	85	f	a75848a4-877f-468e-a6ec-3dbdbbab1b59	\N
1905058	\N	85	f	a7b76bc2-e711-444d-8920-364a390b025a	\N
1905058	\N	85	f	645bec32-ddb6-403a-ada3-25f2e0182e6f	\N
1905058	3738	84	t	cf60c839-3237-471e-b6f2-92fe255430c7	nizam88
1905058	\N	85	f	882f7e26-c51c-4707-bc96-5724b3c443f6	\N
1905058	\N	85	f	95cb1559-a0a8-4fb9-91ab-fb4081e188fc	\N
1905058	\N	85	f	2f37372f-684c-4022-81f3-b4d241a25a5e	\N
1905058	\N	85	f	a66dcf22-d7ca-46de-ab98-47d8f99e3354	\N
1905058	\N	85	f	8c6525d9-60e8-493f-9fe8-9590c05bc5d2	\N
1905058	\N	85	f	5b576cd1-b874-4e2f-8091-a620142c5ebe	\N
1905058	\N	85	f	647f6238-8b06-45d3-b1cb-1cdc86548bf8	\N
1905058	\N	85	f	6e875c6d-d8dc-47c2-adef-d9c70160b44a	\N
1905058	\N	85	f	28df9bb5-a31e-4fdc-ac12-861376b336fa	\N
1905058	\N	85	f	a13866e1-69c6-4414-a7a0-601e8d27fa35	\N
1905058	\N	85	f	f473a706-1ca2-465c-9af0-3c3f863251fd	\N
1905058	\N	85	f	75060e2c-524d-4eba-864f-5fbd12812e4e	\N
1905058	\N	85	f	fd524a4b-321a-46c8-8bcd-7b80f421b37a	\N
1905058	\N	85	f	1edd881e-8768-440e-ad8a-1f60ffa52389	\N
1905058	\N	85	f	5d86b2f0-6bf0-4053-8abc-787074adbb7c	\N
1905058	\N	85	f	968791d2-6e92-4271-812a-14a807471c05	\N
1905058	\N	85	f	218b208a-3ef2-4a26-9714-8d7104b330e8	\N
1905058	\N	85	f	22722fe2-7af9-4039-bda2-98371e50f22e	\N
1905058	\N	85	f	a5c3f46a-00c2-4554-8583-87729ae45bbb	\N
1905058	\N	85	f	d49d2144-818f-4d8f-8eea-14f322f3ef04	\N
1905058	\N	85	f	2e64025b-0148-47d7-971a-2dabf92e6534	\N
1905058	\N	85	f	403af852-5d67-4884-bb44-32a3d4303cf7	\N
1905058	\N	85	f	5b053906-7e5f-4e98-8aa5-16855cf81cc7	\N
1905058	\N	85	f	c882e0b8-69bd-40e9-b501-083d48867984	\N
1905058	\N	85	f	0c8cfc63-0376-4a22-b03d-bef9979dd000	\N
1905058	\N	85	f	9a71f136-50c9-4c80-a424-a05575de2510	\N
1905058	\N	85	f	251d3d7c-bf3a-4141-8e94-5d1a954dfa4f	\N
1905058	\N	85	f	0d14e86e-c22a-4018-ade5-ad7788e0978d	\N
1905058	\N	85	f	5d6ecc27-cf80-4602-8196-08216b1240ab	\N
1905058	\N	85	f	be22e2f8-c605-4502-97cb-51207dd6fd6e	\N
1905058	\N	85	f	9cd09d0f-e254-48fb-9381-844b9ddcb789	\N
1905058	\N	85	f	351719b9-92d2-4530-853b-074af5a99d4d	\N
1905058	\N	85	f	5f11adde-4eb9-4c81-bd4c-c99cce8b3c0a	\N
1905058	\N	85	f	788df2be-2dbf-4916-9c3c-693ec5674199	\N
1905058	\N	85	f	55d24c39-b857-4c5b-866f-153f262c33af	\N
1905058	\N	85	f	aa95b1b4-5dcb-4e04-82c5-d91da1468c5f	\N
1905058	\N	85	f	a57d001f-d18d-477b-aa8d-689466d79297	\N
1905058	\N	85	f	8cf6fa4f-e2d4-49d6-9486-795bd59a9b2e	\N
1905058	\N	85	f	cec0de29-5917-44be-a224-22cff366d8c3	\N
1905058	\N	85	f	12669fe9-a6e5-4bd0-ae33-5c6f0c3a49e1	\N
1905058	\N	85	f	8534ef2f-3a24-47a8-9b10-0ea411335958	\N
1905058	\N	85	f	33b1ff83-54f1-4034-9c78-8adc6fd9cad0	\N
1905058	\N	85	f	f09e13ae-4b4c-4134-bef1-da8f383074b5	\N
1905058	\N	85	f	a9b134ad-6272-46e9-b4de-5131aa055b6a	\N
1905058	\N	85	f	008b0552-ceca-4756-914c-aa24dbfa87ce	\N
1905058	\N	85	f	18a04e9a-580a-41db-831b-19a50a03d9aa	\N
1905058	\N	85	f	0785ba93-3824-4d05-bedf-b6ae3b33704e	\N
1905058	\N	85	f	fbe036cc-fd59-4f6f-8b85-cccaecd6a744	\N
1905058	\N	85	f	2a16f62e-bd60-4c77-badb-9aabf2fac49a	\N
1905058	\N	85	f	64ffbd54-d5a0-4a81-b8f5-7cb3cf730a74	\N
1905058	\N	85	f	daa1b4de-f647-43c5-adc0-b1a675bbe96c	\N
1905058	\N	85	f	d3aa5e20-4825-41ee-b9cd-b8ef03883feb	\N
1905058	\N	85	f	99082f68-7e2c-43f0-8184-c74ab1b64a3e	\N
1905058	\N	85	f	2842f0f1-9a1a-41c3-b106-b4076c33df8c	\N
1905058	\N	85	f	ca138954-cff5-4a85-9a86-54054eeabf4a	\N
1905058	\N	85	f	99ea05ee-f6d9-4d5e-8210-a656ea92232c	\N
1905058	\N	85	f	1373b321-164f-4ccb-9f3f-c7aa88ceed8b	\N
1905058	\N	85	f	014d16a5-251d-44be-8db2-ce02444e0ee5	\N
1905058	\N	85	f	a6a7195d-8790-442d-aee4-54a7759cd8c8	\N
1905058	\N	85	f	f7337959-e128-4c41-a6a3-e66d1d4dc253	\N
1905058	\N	85	f	95fa9965-03fc-42da-98dc-5b9862776d23	\N
1905058	\N	85	f	3dabaec4-554e-47e3-a025-3b4c1108e1af	\N
1905058	\N	85	f	20580440-4177-4267-afc5-a2f2a9bf5aca	\N
1905058	\N	85	f	1d4553d6-97ef-4e8f-86af-31889144b659	\N
1905058	\N	85	f	c56fb7e5-62e1-4e87-9260-64f67df98da1	\N
1905058	\N	85	f	86c48c69-bffe-4909-a5dd-3c06e5330e9a	\N
1905058	\N	85	f	f0fa3c36-481d-4695-bfd3-af23b4ff98c2	\N
1905058	\N	85	f	513f90d5-da7c-4152-bcb9-c2f354b2090b	\N
1905058	\N	85	f	07aefd48-5d53-4e8b-ac59-7d1774a69d86	\N
1905058	\N	85	f	50e9df1d-fb79-47a5-8745-9bacec9893d3	\N
1905058	\N	85	f	ac64f796-8328-4220-a296-b1bc1bf2603c	\N
1905058	\N	85	f	032fcf57-5005-4e4f-b9cb-cfed033932f1	\N
1905058	\N	85	f	e4137b9d-72c6-4537-921c-5219143ea964	\N
1905058	\N	85	f	91a22186-c727-4fbb-b6a5-d541ea243df3	\N
1905058	\N	85	f	b2f6b8b5-b349-4426-8f31-33dd21c516fa	\N
1905058	\N	85	f	3abc7459-adba-4809-814f-677c37d0b07a	\N
1905058	\N	85	f	ae34cbba-f7a4-4d85-aed9-1a777190719f	\N
1905058	\N	85	f	efd6d070-85ab-4275-ac23-47eb12f206d6	\N
1905058	\N	85	f	2ee11ae6-e00c-465a-a202-c0f4ff223a21	\N
1905058	\N	85	f	07b451e2-85e7-48b6-a171-5eabaec88557	\N
1905058	\N	85	f	63f4dd43-bc16-427b-bfb5-85727149f558	\N
1905058	\N	85	f	d0ccff25-6df2-42ed-b49b-5c2eb3a24db5	\N
1905058	\N	85	f	84d96cd0-9c21-4de9-97b4-6ef66d12b160	\N
1905058	\N	85	f	23d62c27-546e-4ef4-a5f5-b4270a8a239d	\N
1905058	\N	85	f	b5059c00-5027-4959-bbe6-abcdf448b219	\N
1905058	\N	85	f	3f90abc5-d867-4169-bf21-c3477ffc3463	\N
1905058	\N	85	f	e1e4ce74-8dd3-47b0-863a-c549ec6d27a1	\N
1905058	\N	85	f	7a13d885-660c-4827-aaaa-846e4370f3e8	\N
1905058	\N	85	f	82121e47-c85d-4730-9ac6-e5005e4a6334	\N
1905058	\N	85	f	eb51c341-7e0c-4e32-8bdc-305faa871e55	\N
1905058	\N	85	f	91f6e836-2f49-4229-bab2-b111fe628e42	\N
1905058	\N	85	f	575b58bd-e9a4-45de-b2cd-4f54cc272c95	\N
1905058	\N	85	f	5f509fa4-dbd3-4ccf-b0c7-f6caecf45052	\N
1905058	\N	85	f	cdee7268-e64d-4b4a-8f9b-ad4f4fff75fe	\N
1905058	\N	85	f	6ef46b81-4b94-43a9-ac8e-7653bcc88902	\N
1905058	\N	85	f	2b072835-0873-4d4c-aaee-06acf33c6f77	\N
1905058	\N	85	f	43218b3f-620e-43ec-8b2b-bd5dcf47fc56	\N
1905058	\N	85	f	9dc5a3dc-f693-4329-a508-62c26ebfaebf	\N
1905058	\N	85	f	8802e246-5ba3-4992-82cb-8e3ba9773cb4	\N
1905058	\N	85	f	a7241af8-370f-4eb9-a4d7-af2a2643ca04	\N
1905058	\N	85	f	3eb7e7d4-0199-42f3-a826-9d8f9decca17	\N
1905058	\N	85	f	dc66c941-adb4-47f8-b9e6-352b32b75482	\N
1905058	\N	85	f	b4108603-1e03-4cbf-a297-47b34f248022	\N
1905058	\N	85	f	51201afd-e05e-4be4-9339-f1f4f9b023cc	\N
1905058	\N	85	f	a2276969-dc94-4f73-92a1-7cd916b1d1ba	\N
1905058	\N	85	f	4cdc44a5-18b3-4004-a324-61cba7202d8c	\N
1905058	\N	85	f	1ddf2f0d-d111-464e-ae44-163261fdf646	\N
1905058	\N	85	f	f56aeeb9-299c-40a4-bb76-8967c23a1ab1	\N
1905058	\N	85	f	b840cecb-846a-4a4d-8975-27a8e968bab5	\N
1905058	\N	85	f	717f1a6c-b562-423e-9405-9d6e13f4343c	\N
1905058	\N	85	f	d58fd67d-bc4d-49fd-9b2a-5d2b56b84444	\N
1905058	\N	85	f	44389dea-cb3e-47ab-ac1e-9c69f84b1ffb	\N
1905058	\N	85	f	c3e758bf-2d6d-46a1-98e7-fd263c32f94b	\N
1905058	\N	85	f	8366ad90-eeaa-4923-9bbb-66e7d6970448	\N
1905058	\N	85	f	3a82b6fa-c277-432a-b167-ee4e602f3499	\N
1905058	\N	85	f	8c756cdc-2f67-4615-a38d-a6b5f75d6ffe	\N
1905058	\N	85	f	cf7a6626-a6c0-4c6d-a14f-620d86cc32f0	\N
1905058	\N	85	f	5bd9d061-8e02-4328-80c5-3643d6e14dd8	\N
1905058	\N	85	f	ddef2df1-9e80-4bcc-bec6-6a9f60834062	\N
1905058	\N	85	f	b728dfb4-3d32-42c6-bc10-3c7d71b393b0	\N
1905058	\N	85	f	e558ae26-860c-4873-860a-65342e8e33b6	\N
1905058	\N	85	f	6b7002ff-72a0-44e6-bade-c5ae8630575e	\N
1905058	\N	85	f	050b7e1f-1022-4a94-861a-28a136b80a02	\N
1905058	\N	85	f	649e6dcb-f4b2-4e4e-9af3-12f0da23ce2a	\N
1905058	\N	85	f	834e7dd4-46e9-45ca-bd7b-c0be215c6ad5	\N
1905058	\N	85	f	da75ac26-6e71-4956-9388-06a87d282c7f	\N
1905058	\N	85	f	e45db4e9-8c22-41fa-a005-9f4782c3ab8e	\N
1905058	\N	85	f	dc893633-ff13-4eb6-9f24-826f7e9d5795	\N
1905058	\N	85	f	a1be30b9-7108-4d6f-a5d4-3c9bfdf8b507	\N
1905058	\N	85	f	2a9132c1-6279-40d3-b7fe-bfcafa234688	\N
1905058	\N	85	f	980f60b4-7b86-4bea-814e-191849bf237e	\N
1905058	\N	85	f	e4dcdb79-fc57-4b86-b7a8-94953fed65ee	\N
1905058	\N	85	f	5ba865d1-00c3-4a30-8e8d-3eb27ec50981	\N
1905058	\N	85	f	84e61bdd-bd43-4666-88dd-be2a9bb4932b	\N
1905058	\N	85	f	711970b0-8c8a-4a69-ae11-f83f5f110d4c	\N
1905058	\N	85	f	2f1279e6-7fc7-4c23-87cc-c88fabcdc6a4	\N
1905058	\N	85	f	d12acea5-76ec-46e7-b10b-d6131dc19ae4	\N
1905058	\N	85	f	5fbb5c80-6892-4b37-bc3f-5277f1d64b70	\N
1905058	\N	85	f	3538a95c-01ef-4b03-af78-d849df0d1c80	\N
1905058	\N	85	f	f70cfe2a-efe7-4348-b271-20fc47b23a67	\N
1905058	\N	85	f	8aeeeb61-ef9c-4350-91ac-040daea6ce7f	\N
1905058	\N	85	f	3371930c-87b8-4ba8-bbf2-e55084715699	\N
1905084	2161	51	t	03d51151-8525-403e-8651-b46bb95ba394	\N
\.


--
-- Data for Name: trip; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trip (id, start_timestamp, route, time_type, time_list, travel_direction, bus, is_default, driver, approved_by, end_timestamp, start_location, end_location, path, is_live, passenger_count, helper, valid, time_window) FROM stdin;
1958	2024-01-31 01:34:00.489636+06	5	afternoon	{"(36,\\"2024-02-01 19:40:00+06\\")","(37,\\"2024-02-01 19:50:00+06\\")","(38,\\"2024-02-01 19:55:00+06\\")","(39,\\"2024-02-01 20:00:00+06\\")","(40,\\"2024-02-01 20:07:00+06\\")","(70,\\"2024-02-01 20:10:00+06\\")"}	from_buet	Ba-22-4326	t	rafiqul	nazmul	2024-01-31 01:58:43.640821+06	(23.76237,90.35889)	(23.7278344,90.3910436)	{"(23.7623489,90.358887)","(23.7663533,90.3648367)","(23.7655104,90.3651403)","(23.7646664,90.3654348)","(23.7641944,90.3652159)","(23.7640314,90.3646332)","(23.7638582,90.3640017)","(23.763682,90.3633785)","(23.7635197,90.3628186)","(23.76334,90.3622083)","(23.7631566,90.3616031)","(23.7629762,90.3609855)","(23.7628117,90.3603567)","(23.7626414,90.3597687)","(23.7624553,90.3591464)","(23.7620753,90.3588786)","(23.7615786,90.3589119)","(23.7610516,90.3589305)","(23.7605511,90.3588835)","(23.7600263,90.3589248)","(23.7595375,90.3590761)","(23.7590781,90.3592982)","(23.7586213,90.3595548)","(23.7581814,90.3598812)","(23.7577712,90.3602328)","(23.7574001,90.3606268)","(23.7571153,90.3610577)","(23.7567658,90.3618999)","(23.7562055,90.3625783)","(23.7556434,90.3632366)","(23.75512,90.3638618)","(23.75458,90.3645316)","(23.7540433,90.3651785)","(23.75352,90.3657835)","(23.7529799,90.3664234)","(23.7524978,90.3669876)","(23.7517913,90.3676036)","(23.7511659,90.3680588)","(23.7504509,90.3685497)","(23.7497367,90.3690418)","(23.7490434,90.369525)","(23.74837,90.3699901)","(23.7477591,90.3704005)","(23.7470341,90.3708881)","(23.7463433,90.37136)","(23.7456102,90.3718518)","(23.7449232,90.3723101)","(23.7442483,90.3727416)","(23.7436292,90.3731604)","(23.7429011,90.3736597)","(23.7422153,90.3740487)","(23.7414977,90.3744266)","(23.7407603,90.3748002)","(23.7400468,90.3751518)","(23.7393131,90.3755332)","(23.7385949,90.3759168)","(23.7385433,90.3758267)","(23.7390717,90.3755345)","(23.7395864,90.3752647)","(23.7387134,90.3758541)","(23.7385722,90.3778198)","(23.7388566,90.3795551)","(23.7396279,90.3807628)","(23.7403133,90.3815189)","(23.7406496,90.3831105)","(23.739228,90.3833956)","(23.7379529,90.3837217)","(23.7367137,90.3839936)","(23.7354392,90.3842999)","(23.7341904,90.38461)","(23.7327824,90.3849899)","(23.7325079,90.386185)","(23.7322001,90.387033)","(23.73019,90.3873201)","(23.7286641,90.3883909)","(23.7279262,90.3891317)","(23.7272991,90.389751)","(37.4226711,-122.0849872)","(23.72723,90.38992)","(23.7276533,90.390254)","(23.727735,90.3907998)"}	f	0	reyazul	t	\N
1004	2024-01-27 23:28:31.997913+06	3	evening	{"(17,\\"2024-02-14 23:30:00+06\\")","(18,\\"2024-02-14 23:45:00+06\\")","(19,\\"2024-02-14 23:48:00+06\\")","(20,\\"2024-02-14 23:50:00+06\\")","(21,\\"2024-02-14 23:52:00+06\\")","(22,\\"2024-02-14 23:54:00+06\\")","(23,\\"2024-02-14 23:56:00+06\\")","(24,\\"2024-02-14 23:58:00+06\\")","(25,\\"2024-02-14 00:00:00+06\\")","(26,\\"2024-02-14 00:02:00+06\\")","(70,\\"2024-02-14 00:04:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-27 23:30:27.272595+06	\N	\N	\N	f	0	rashid56	t	\N
1038	2024-01-27 23:33:34.268594+06	7	morning	{"(50,\\"2024-02-04 12:40:00+06\\")","(51,\\"2024-02-04 12:42:00+06\\")","(52,\\"2024-02-04 12:43:00+06\\")","(53,\\"2024-02-04 12:46:00+06\\")","(54,\\"2024-02-04 12:47:00+06\\")","(55,\\"2024-02-04 12:48:00+06\\")","(56,\\"2024-02-04 12:50:00+06\\")","(57,\\"2024-02-04 12:52:00+06\\")","(58,\\"2024-02-04 12:53:00+06\\")","(59,\\"2024-02-04 12:54:00+06\\")","(60,\\"2024-02-04 12:56:00+06\\")","(61,\\"2024-02-04 12:58:00+06\\")","(62,\\"2024-02-04 13:00:00+06\\")","(63,\\"2024-02-04 13:02:00+06\\")","(70,\\"2024-02-04 13:00:00+06\\")"}	to_buet	Ba-35-1461	t	sohel55	nazmul	2024-01-27 23:33:45.29544+06	\N	\N	\N	f	0	rashid56	t	\N
1039	2024-01-27 23:36:13.687176+06	7	afternoon	{"(50,\\"2024-02-04 19:40:00+06\\")","(51,\\"2024-02-04 19:48:00+06\\")","(52,\\"2024-02-04 19:50:00+06\\")","(53,\\"2024-02-04 19:52:00+06\\")","(54,\\"2024-02-04 19:54:00+06\\")","(55,\\"2024-02-04 19:56:00+06\\")","(56,\\"2024-02-04 19:58:00+06\\")","(57,\\"2024-02-04 20:00:00+06\\")","(58,\\"2024-02-04 20:02:00+06\\")","(59,\\"2024-02-04 20:04:00+06\\")","(60,\\"2024-02-04 20:06:00+06\\")","(61,\\"2024-02-04 20:08:00+06\\")","(62,\\"2024-02-04 20:10:00+06\\")","(63,\\"2024-02-04 20:12:00+06\\")","(70,\\"2024-02-04 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	sohel55	nazmul	2024-01-27 23:36:26.395124+06	\N	\N	\N	f	0	rashid56	t	\N
1040	2024-01-27 23:43:56.679781+06	7	evening	{"(50,\\"2024-02-04 23:30:00+06\\")","(51,\\"2024-02-04 23:38:00+06\\")","(52,\\"2024-02-04 23:40:00+06\\")","(53,\\"2024-02-04 23:42:00+06\\")","(54,\\"2024-02-04 23:44:00+06\\")","(55,\\"2024-02-04 23:46:00+06\\")","(56,\\"2024-02-04 23:48:00+06\\")","(57,\\"2024-02-04 23:50:00+06\\")","(58,\\"2024-02-04 23:52:00+06\\")","(59,\\"2024-02-04 23:54:00+06\\")","(60,\\"2024-02-04 23:56:00+06\\")","(61,\\"2024-02-04 23:58:00+06\\")","(62,\\"2024-02-04 00:00:00+06\\")","(63,\\"2024-02-04 00:02:00+06\\")","(70,\\"2024-02-04 00:04:00+06\\")"}	from_buet	Ba-35-1461	t	sohel55	nazmul	2024-01-27 23:48:50.815707+06	\N	\N	\N	f	0	rashid56	t	\N
1098	2024-01-28 00:18:54.862311+06	3	morning	{"(17,\\"2024-02-17 12:40:00+06\\")","(18,\\"2024-02-17 12:42:00+06\\")","(19,\\"2024-02-17 12:44:00+06\\")","(20,\\"2024-02-17 12:46:00+06\\")","(21,\\"2024-02-17 12:48:00+06\\")","(22,\\"2024-02-17 12:50:00+06\\")","(23,\\"2024-02-17 12:52:00+06\\")","(24,\\"2024-02-17 12:54:00+06\\")","(25,\\"2024-02-17 12:57:00+06\\")","(26,\\"2024-02-17 13:00:00+06\\")","(70,\\"2024-02-17 13:15:00+06\\")"}	to_buet	Ba-35-1461	t	altaf	nazmul	2024-01-28 00:23:03.782982+06	\N	\N	\N	f	0	rashid56	t	\N
1099	2024-01-28 00:24:57.065157+06	3	afternoon	{"(17,\\"2024-02-17 19:40:00+06\\")","(18,\\"2024-02-17 19:55:00+06\\")","(19,\\"2024-02-17 19:58:00+06\\")","(20,\\"2024-02-17 20:00:00+06\\")","(21,\\"2024-02-17 20:02:00+06\\")","(22,\\"2024-02-17 20:04:00+06\\")","(23,\\"2024-02-17 20:06:00+06\\")","(24,\\"2024-02-17 20:08:00+06\\")","(25,\\"2024-02-17 20:10:00+06\\")","(26,\\"2024-02-17 20:12:00+06\\")","(70,\\"2024-02-17 20:14:00+06\\")"}	from_buet	Ba-35-1461	t	altaf	nazmul	2024-01-28 00:30:26.241063+06	\N	\N	\N	f	0	rashid56	t	\N
2197	2024-02-09 10:17:39.988862+06	5	morning	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:17:44.951+06\\")"}	to_buet	Ba-98-5568	t	ibrahim	nazmul	2024-02-09 10:24:21.196096+06	(23.7276,90.3917)	(23.7275682,90.3917004)	{"(23.7275743,90.3917007)"}	f	0	khairul	t	\N
1941	2024-01-30 18:51:48.390011+06	7	evening	{"(50,\\"2024-01-30 23:30:00+06\\")","(51,\\"2024-01-30 23:38:00+06\\")","(52,\\"2024-01-30 23:40:00+06\\")","(53,\\"2024-01-30 23:42:00+06\\")","(54,\\"2024-01-30 23:44:00+06\\")","(55,\\"2024-01-30 23:46:00+06\\")","(56,\\"2024-01-30 23:48:00+06\\")","(57,\\"2024-01-30 23:50:00+06\\")","(58,\\"2024-01-30 23:52:00+06\\")","(59,\\"2024-01-30 23:54:00+06\\")","(60,\\"2024-01-30 23:56:00+06\\")","(61,\\"2024-01-30 23:58:00+06\\")","(62,\\"2024-01-30 00:00:00+06\\")","(63,\\"2024-01-30 00:02:00+06\\")","(70,\\"2024-01-30 00:04:00+06\\")"}	from_buet	Ba-46-1334	t	sohel55	\N	2024-01-30 18:55:06.87056+06	(23.7664933,90.3647317)	(23.7664737,90.3647329)	{"(23.7664569,90.3647362)"}	f	0	nasir81	t	\N
1990	2024-01-30 18:59:28.377695+06	1	morning	{"(1,\\"2024-02-05 12:15:00+06\\")","(2,\\"2024-02-05 12:18:00+06\\")","(3,\\"2024-02-05 12:20:00+06\\")","(4,\\"2024-02-05 12:23:00+06\\")","(5,\\"2024-02-05 12:26:00+06\\")","(6,\\"2024-02-05 12:29:00+06\\")","(7,\\"2024-02-05 12:49:00+06\\")","(8,\\"2024-02-05 12:51:00+06\\")","(9,\\"2024-02-05 12:53:00+06\\")","(10,\\"2024-02-05 12:55:00+06\\")","(11,\\"2024-02-05 12:58:00+06\\")","(70,\\"2024-02-05 13:05:00+06\\")"}	to_buet	Ba-19-0569	t	altaf	nazmul	2024-01-30 19:02:06.40486+06	(23.7664933,90.3647317)	(23.7664716,90.3647332)	{"(23.7664933,90.3647317)"}	f	0	siddiq2	t	\N
2198	2024-02-18 10:24:34.991175+06	3	afternoon	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:24:39.958+06\\")"}	from_buet	Ba-98-5568	t	ibrahim	nazmul	2024-02-09 10:26:15.403943+06	(23.7276,90.3917)	(23.7275686,90.3917004)	{"(23.7275743,90.3917007)"}	f	38	khairul	t	\N
2139	2024-02-11 21:33:42.761323+06	8	evening	{NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-11 21:36:20.74+06\\")"}	from_buet	Ba-36-1921	t	rafiqul	nazmul	2024-02-11 21:36:32.512621+06	(23.7275204,90.3917006)	(23.7275403,90.3917006)	{"(23.7276,90.3917)"}	f	34	rashid56	t	\N
2769	2024-04-18 08:51:36.499417+06	6	afternoon	{"(70,\\"2024-03-04 08:51:49.197+06\\")",NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-12-8888	t	abdulkarim6	nazmul	2024-03-04 08:52:52.862309+06	(23.736185,90.3839567)	(23.7259954,90.3918351)	{"(23.736185,90.3839567)","(23.736185,90.3839567)","(23.7271754,90.3917167)","(23.726539,90.3917349)","(23.7260771,90.3918199)"}	f	0	shamsul54	t	{"2024-03-04 08:51:36.499+06","2024-03-04 08:51:39.225+06","2024-03-04 08:51:49.197+06","2024-03-04 08:52:13.151+06","2024-03-04 08:52:34.136+06"}
1155	2024-01-28 02:27:41.406627+06	6	morning	{"(41,\\"2024-01-29 12:40:00+06\\")","(42,\\"2024-01-29 12:42:00+06\\")","(43,\\"2024-01-29 12:45:00+06\\")","(44,\\"2024-01-29 12:47:00+06\\")","(45,\\"2024-01-29 12:49:00+06\\")","(46,\\"2024-01-29 12:51:00+06\\")","(47,\\"2024-01-29 12:52:00+06\\")","(48,\\"2024-01-29 12:53:00+06\\")","(49,\\"2024-01-29 12:54:00+06\\")","(70,\\"2024-01-29 13:10:00+06\\")"}	to_buet	Ba-17-2081	t	altaf	nazmul	2024-01-28 02:28:25.45167+06	\N	\N	{"(23.7646853,90.3621754)","(23.7647807,90.3633323)","(23.7638179,90.3638189)"}	f	0	rashid56	t	\N
1156	2024-01-28 02:40:01.793866+06	6	afternoon	{"(41,\\"2024-01-29 19:40:00+06\\")","(42,\\"2024-01-29 19:56:00+06\\")","(43,\\"2024-01-29 19:58:00+06\\")","(44,\\"2024-01-29 20:00:00+06\\")","(45,\\"2024-01-29 20:02:00+06\\")","(46,\\"2024-01-29 20:04:00+06\\")","(47,\\"2024-01-29 20:06:00+06\\")","(48,\\"2024-01-29 20:08:00+06\\")","(49,\\"2024-01-29 20:10:00+06\\")","(70,\\"2024-01-29 20:12:00+06\\")"}	from_buet	Ba-17-2081	t	altaf	nazmul	2024-01-28 02:41:04.128471+06	\N	\N	{"(23.764785,90.362795)","(23.764785,90.362795)","(23.7641433,90.3635413)","(23.7641433,90.3635413)","(23.7629328,90.3644588)","(23.7629328,90.3644588)","(23.7619764,90.3647657)","(23.7619764,90.3647657)"}	f	0	rashid56	t	\N
1140	2024-01-28 03:05:49.773112+06	8	morning	{"(64,\\"2024-01-28 12:10:00+06\\")","(65,\\"2024-01-28 12:13:00+06\\")","(66,\\"2024-01-28 12:18:00+06\\")","(67,\\"2024-01-28 12:20:00+06\\")","(68,\\"2024-01-28 12:22:00+06\\")","(69,\\"2024-01-28 12:25:00+06\\")","(70,\\"2024-01-28 12:40:00+06\\")"}	to_buet	Ba-83-8014	t	ibrahim	nazmul	2024-01-28 03:06:57.62416+06	(23.762675,90.3645433)	(23.7610135,90.3651185)	{"(23.7626585,90.364548)","(23.7649167,90.363245)","(23.7639681,90.3636351)","(23.7626791,90.3645418)","(23.7617005,90.3648539)"}	f	0	mahbub777	t	\N
1203	2024-01-28 03:35:02.834051+06	6	morning	{"(41,\\"2024-02-01 12:40:00+06\\")","(42,\\"2024-02-01 12:42:00+06\\")","(43,\\"2024-02-01 12:45:00+06\\")","(44,\\"2024-02-01 12:47:00+06\\")","(45,\\"2024-02-01 12:49:00+06\\")","(46,\\"2024-02-01 12:51:00+06\\")","(47,\\"2024-02-01 12:52:00+06\\")","(48,\\"2024-02-01 12:53:00+06\\")","(49,\\"2024-02-01 12:54:00+06\\")","(70,\\"2024-02-01 13:10:00+06\\")"}	to_buet	Ba-48-5757	t	ibrahim	nazmul	2024-01-28 03:35:45.077402+06	(23.76481,90.36288)	(23.7623159,90.3646402)	{"(23.7648229,90.3629289)","(23.763818,90.3638189)","(23.7624585,90.3646186)"}	f	0	rashid56	t	\N
1141	2024-01-28 03:18:47.160923+06	8	afternoon	{"(64,\\"2024-01-28 19:40:00+06\\")","(65,\\"2024-01-28 19:55:00+06\\")","(66,\\"2024-01-28 19:58:00+06\\")","(67,\\"2024-01-28 20:01:00+06\\")","(68,\\"2024-01-28 20:04:00+06\\")","(69,\\"2024-01-28 20:07:00+06\\")","(70,\\"2024-01-28 20:10:00+06\\")"}	from_buet	Ba-83-8014	t	ibrahim	nazmul	2024-01-28 03:19:30.927914+06	(23.7607998,90.3651584)	(23.7632479,90.3643324)	{"(23.7608562,90.3651593)","(23.7646898,90.3623264)","(23.7647391,90.3633399)","(23.7637288,90.3636801)"}	f	0	mahbub777	t	\N
1142	2024-01-28 03:30:32.69161+06	8	evening	{"(64,\\"2024-01-28 23:30:00+06\\")","(65,\\"2024-01-28 23:45:00+06\\")","(66,\\"2024-01-28 23:48:00+06\\")","(67,\\"2024-01-28 23:51:00+06\\")","(68,\\"2024-01-28 23:54:00+06\\")","(69,\\"2024-01-28 23:57:00+06\\")","(70,\\"2024-01-28 00:00:00+06\\")"}	from_buet	Ba-83-8014	t	ibrahim	nazmul	2024-01-28 03:31:40.217163+06	(23.7630383,90.364425)	(23.7615237,90.3649582)	{"(23.7630204,90.3644298)","(23.76468,90.36243)","(23.7645307,90.3634049)","(23.7638345,90.3641268)","(23.7623752,90.3646502)"}	f	0	mahbub777	t	\N
1157	2024-01-28 02:49:23.596861+06	6	evening	{"(41,\\"2024-01-29 23:30:00+06\\")","(42,\\"2024-01-29 23:46:00+06\\")","(43,\\"2024-01-29 23:48:00+06\\")","(44,\\"2024-01-29 23:50:00+06\\")","(45,\\"2024-01-29 23:52:00+06\\")","(46,\\"2024-01-29 23:54:00+06\\")","(47,\\"2024-01-29 23:56:00+06\\")","(48,\\"2024-01-29 23:58:00+06\\")","(49,\\"2024-01-29 00:00:00+06\\")","(70,\\"2024-01-29 00:02:00+06\\")"}	from_buet	Ba-17-2081	t	altaf	nazmul	2024-01-28 02:50:10.720968+06	\N	(23.7383,90.44334)	{"(23.764715,90.3625517)","(23.764715,90.3625517)","(23.764715,90.3625517)","(23.7638773,90.3640616)","(23.7638773,90.3640616)","(23.7638773,90.3640616)","(23.7630047,90.3644121)","(23.7630047,90.3644121)","(23.7630047,90.3644121)"}	f	0	rashid56	t	\N
2546	2024-02-27 23:31:33.574613+06	5	afternoon	{"(36,\\"2024-02-17 19:40:00+06\\")","(37,\\"2024-02-17 19:50:00+06\\")","(38,\\"2024-02-17 19:55:00+06\\")","(39,\\"2024-02-17 20:00:00+06\\")","(40,\\"2024-02-17 20:07:00+06\\")","(70,\\"2024-02-17 20:10:00+06\\")"}	from_buet	Ba-36-1921	t	sohel55	nazmul	2024-02-15 23:45:05.487937+06	(23.765385,90.365185)	(23.7653674,90.3651873)	{"(23.765385,90.365185)"}	f	0	alamgir	t	\N
2170	2024-02-10 21:37:37.748761+06	4	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-11 21:37:42.749+06\\")"}	to_buet	Ba-85-4722	t	rafiqul	nazmul	2024-02-11 22:32:05.160215+06	(23.7276,90.3917)	(23.7626156,90.3701977)	{"(23.7275501,90.3917011)"}	f	0	zahir53	t	\N
3063	2024-04-21 08:59:49.599375+06	5	afternoon	{"(70,\\"2024-03-04 08:59:52.07+06\\")",NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	2024-03-04 09:04:10.147554+06	(23.726735,90.391705)	(23.7323851,90.3857755)	{"(23.726735,90.391705)","(23.7267002,90.3917103)","(23.7261204,90.3918116)","(23.7263029,90.3909704)","(23.7265896,90.3905522)","(23.7268996,90.3901321)","(23.7272019,90.3897302)","(23.7278568,90.3890933)","(23.7282398,90.38877)","(23.7286963,90.3883714)","(23.7291038,90.3880104)","(23.7295118,90.3876852)","(23.7299159,90.3874656)","(23.7304149,90.3872558)","(23.7308508,90.387105)","(23.7313765,90.3869856)","(23.732179,90.3869178)","(23.7324802,90.3864974)","(23.7323851,90.3857755)"}	f	31	mahbub777	t	{"2024-03-04 09:02:12.051+06","2024-03-04 09:02:22.047+06","2024-03-04 09:02:32.073+06","2024-03-04 09:02:42.064+06","2024-03-04 09:02:52.054+06","2024-03-04 09:03:02.085+06","2024-03-04 09:03:12.086+06","2024-03-04 09:03:25.146+06","2024-03-04 09:03:46.602+06","2024-03-04 09:04:07.594+06"}
1162	2024-01-28 03:52:19.424902+06	1	afternoon	{"(1,\\"2024-01-29 19:40:00+06\\")","(2,\\"2024-01-29 19:47:00+06\\")","(3,\\"2024-01-29 19:50:00+06\\")","(4,\\"2024-01-29 19:52:00+06\\")","(5,\\"2024-01-29 19:54:00+06\\")","(6,\\"2024-01-29 20:06:00+06\\")","(7,\\"2024-01-29 20:09:00+06\\")","(8,\\"2024-01-29 20:12:00+06\\")","(9,\\"2024-01-29 20:15:00+06\\")","(10,\\"2024-01-29 20:18:00+06\\")","(11,\\"2024-01-29 20:21:00+06\\")","(70,\\"2024-01-29 20:24:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	2024-01-28 04:24:11.687318+06	(23.75632,90.3641017)	(23.7275826,90.3917008)	{"(23.75632,90.3641017)","(23.7552009,90.3641389)","(23.7544482,90.3647013)","(23.7536596,90.3656218)","(23.7528312,90.3666003)","(23.7519332,90.3674972)","(23.7511598,90.3680533)","(23.7502049,90.3687171)","(23.7491714,90.3694372)","(23.7483965,90.3699624)","(23.7474082,90.3706356)","(23.7463798,90.3713339)","(23.7455886,90.3718562)","(23.7446149,90.3725005)","(23.7438287,90.3730144)","(23.7428648,90.3736806)","(23.7420425,90.374115)","(23.7410082,90.3746741)","(23.7401806,90.3750763)","(23.7391616,90.3756091)","(23.7384099,90.3765045)","(23.7385368,90.3775494)","(23.7387081,90.3788031)","(23.7388976,90.3797904)","(23.7392359,90.380841)","(23.7401354,90.3806777)","(23.740358,90.3818204)","(23.7405714,90.3829354)","(23.7395909,90.3833197)","(23.7386776,90.3835081)","(23.7377446,90.3837713)","(23.736841,90.3839697)","(23.7359126,90.3841714)","(23.7350143,90.384413)","(23.7340661,90.3846397)","(23.7331694,90.3848863)","(23.7324898,90.385719)","(23.7325996,90.3867607)","(23.7314599,90.386967)","(23.7304914,90.3872093)","(23.7296013,90.387629)","(23.7287833,90.3882836)","(23.7280026,90.3890557)","(23.7273257,90.3897197)","(23.7277163,90.3907071)","(23.7280587,90.3916682)"}	f	0	farid99	t	\N
1163	2024-01-28 04:24:47.12721+06	1	evening	{"(1,\\"2024-01-29 23:30:00+06\\")","(2,\\"2024-01-29 23:37:00+06\\")","(3,\\"2024-01-29 23:40:00+06\\")","(4,\\"2024-01-29 23:42:00+06\\")","(5,\\"2024-01-29 23:44:00+06\\")","(6,\\"2024-01-29 23:56:00+06\\")","(7,\\"2024-01-29 23:59:00+06\\")","(8,\\"2024-01-29 00:02:00+06\\")","(9,\\"2024-01-29 00:05:00+06\\")","(10,\\"2024-01-29 00:08:00+06\\")","(11,\\"2024-01-29 00:11:00+06\\")","(70,\\"2024-01-29 00:14:00+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	2024-01-28 04:38:22.901212+06	(23.7276,90.3917)	(23.74363,90.37316)	{"(23.7276,90.3917)","(23.7647037,90.3622592)","(23.7648629,90.3633074)","(23.7638522,90.3639699)","(23.7629304,90.3644598)","(23.762062,90.3647632)","(23.7611915,90.3650536)","(23.7601869,90.3654399)","(23.7593104,90.3657095)","(23.758807,90.3645671)","(23.7582435,90.3634954)","(23.7571685,90.3638249)","(23.7560853,90.3641782)","(23.7550852,90.3640086)","(23.7542803,90.3649014)","(23.7534304,90.3658863)","(23.7525971,90.3668714)","(23.7516004,90.367748)","(23.7505598,90.3684734)","(23.7495101,90.3691982)","(23.7484634,90.3699249)","(23.7474068,90.3706366)","(23.7463784,90.3713349)","(23.7453051,90.3720566)","(23.744265,90.3727299)"}	f	0	farid99	t	\N
1179	2024-01-28 04:39:14.082505+06	6	morning	{"(41,\\"2024-01-30 12:40:00+06\\")","(42,\\"2024-01-30 12:42:00+06\\")","(43,\\"2024-01-30 12:45:00+06\\")","(44,\\"2024-01-30 12:47:00+06\\")","(45,\\"2024-01-30 12:49:00+06\\")","(46,\\"2024-01-30 12:51:00+06\\")","(47,\\"2024-01-30 12:52:00+06\\")","(48,\\"2024-01-30 12:53:00+06\\")","(49,\\"2024-01-30 12:54:00+06\\")","(70,\\"2024-01-30 13:10:00+06\\")"}	to_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-28 04:41:34.665157+06	(23.743595,90.3731833)	(23.7594097,90.3656727)	{"(23.743595,90.3731833)","(23.7645149,90.3634097)","(23.7635965,90.3642248)","(23.7626683,90.3645331)","(23.7615213,90.3649592)","(23.760607,90.3652536)","(23.7597444,90.3655642)"}	f	0	khairul	t	\N
1180	2024-01-28 04:43:25.349017+06	6	afternoon	{"(41,\\"2024-01-30 19:40:00+06\\")","(42,\\"2024-01-30 19:56:00+06\\")","(43,\\"2024-01-30 19:58:00+06\\")","(44,\\"2024-01-30 20:00:00+06\\")","(45,\\"2024-01-30 20:02:00+06\\")","(46,\\"2024-01-30 20:04:00+06\\")","(47,\\"2024-01-30 20:06:00+06\\")","(48,\\"2024-01-30 20:08:00+06\\")","(49,\\"2024-01-30 20:10:00+06\\")","(70,\\"2024-01-30 20:12:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-28 05:07:47.276301+06	(23.76293,90.36446)	(23.7275691,90.3917004)	{"(23.7629215,90.3644627)","(23.761893,90.3648211)","(23.760958,90.3651252)","(23.7598395,90.3655478)","(23.7590257,90.3650313)","(23.7583038,90.3636066)","(23.757252,90.3637957)","(23.7561769,90.364146)","(23.7551482,90.3640747)","(23.7540848,90.3651296)","(23.7529648,90.3664414)","(23.7517438,90.3676471)","(23.7503818,90.3685942)","(23.7490333,90.3695325)","(23.7482115,90.370075)","(23.7469167,90.3709675)","(23.7460972,90.3714986)","(23.7448431,90.372356)","(23.7440218,90.3728745)","(23.7426887,90.3737957)","(23.7418545,90.3741857)","(23.7404619,90.374948)","(23.7396228,90.3753398)","(23.7384031,90.376188)","(23.7384991,90.3771824)","(23.7386299,90.3782604)","(23.738924,90.3798963)","(23.739104,90.380962)","(23.7401694,90.3808655)","(23.740456,90.3823275)","(23.7399628,90.3832297)","(23.7388421,90.3834792)","(23.7376836,90.3837859)","(23.7364057,90.3840543)","(23.7352299,90.3843543)","(23.7339625,90.3846692)","(23.7327725,90.3850195)","(23.7325149,90.3861182)","(23.7320907,90.387031)","(23.7303474,90.3872618)","(23.7294433,90.3877279)","(23.7286687,90.3883896)","(23.7279292,90.3891291)","(23.727264,90.3898125)","(23.7279039,90.3912376)"}	f	0	khairul	t	\N
1181	2024-01-28 05:14:11.476372+06	6	evening	{"(41,\\"2024-01-30 23:30:00+06\\")","(42,\\"2024-01-30 23:46:00+06\\")","(43,\\"2024-01-30 23:48:00+06\\")","(44,\\"2024-01-30 23:50:00+06\\")","(45,\\"2024-01-30 23:52:00+06\\")","(46,\\"2024-01-30 23:54:00+06\\")","(47,\\"2024-01-30 23:56:00+06\\")","(48,\\"2024-01-30 23:58:00+06\\")","(49,\\"2024-01-30 00:00:00+06\\")","(70,\\"2024-01-30 00:02:00+06\\")"}	from_buet	Ba-24-8518	t	sohel55	nazmul	2024-01-28 05:24:01.704883+06	(23.7605667,90.3652883)	(23.7335124,90.3847891)	{"(23.760503,90.3653183)","(23.7594967,90.3656476)","(23.7587519,90.3644617)","(23.7578897,90.3635623)","(23.7568074,90.3639391)","(23.7557618,90.364289)","(23.7547689,90.3642993)","(23.7541415,90.3650692)","(23.7530767,90.3663061)","(23.7519004,90.3675201)","(23.7511399,90.368056)","(23.7498637,90.368954)","(23.7490843,90.3694787)","(23.7477634,90.3703976)","(23.7469662,90.370914)","(23.74566,90.3718175)","(23.7442341,90.3727505)","(23.7428323,90.3737021)","(23.7414635,90.3744477)","(23.7405702,90.3748659)","(23.7392135,90.3755876)","(23.7384338,90.3760968)","(23.7384761,90.3771184)","(23.7386995,90.3787562)","(23.7388878,90.379826)","(23.739499,90.3807819)","(23.7402677,90.3813673)","(23.740556,90.3828572)","(23.7396403,90.3833063)","(23.7384407,90.3835694)","(23.7371857,90.3838975)","(23.7359756,90.3841543)","(23.7347394,90.3844857)","(23.7335124,90.3847891)"}	f	0	khairul	t	\N
2327	2024-02-11 23:02:30.3872+06	1	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-71-7930	t	rafiqul	nazmul	2024-02-11 23:11:47.548794+06	(23.7626383,90.3702141)	(23.7626819,90.3702064)	{}	f	61	jamal7898	t	\N
2199	2024-02-18 10:26:26.98145+06	2	evening	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:26:31.997+06\\")"}	from_buet	Ba-98-5568	t	ibrahim	nazmul	2024-02-09 10:28:11.929196+06	(23.7275684,90.3917004)	(23.7275686,90.3917004)	{"(23.7275675,90.3917007)"}	f	28	khairul	t	\N
1991	2024-01-30 19:02:09.106701+06	1	afternoon	{"(1,\\"2024-02-05 19:40:00+06\\")","(2,\\"2024-02-05 19:47:00+06\\")","(3,\\"2024-02-05 19:50:00+06\\")","(4,\\"2024-02-05 19:52:00+06\\")","(5,\\"2024-02-05 19:54:00+06\\")","(6,\\"2024-02-05 20:06:00+06\\")","(7,\\"2024-02-05 20:09:00+06\\")","(8,\\"2024-02-05 20:12:00+06\\")","(9,\\"2024-02-05 20:15:00+06\\")","(10,\\"2024-02-05 20:18:00+06\\")","(11,\\"2024-02-05 20:21:00+06\\")","(70,\\"2024-02-05 20:24:00+06\\")"}	from_buet	Ba-19-0569	t	altaf	nazmul	2024-01-30 19:09:06.146212+06	(23.7664716,90.3647332)	(23.7664916,90.3647319)	{"(23.7664933,90.3647317)"}	f	0	siddiq2	t	\N
2545	2024-02-15 23:56:41.774477+06	5	morning	{"(36,\\"2024-02-15 23:56:46.643+06\\")",NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-36-1921	t	sohel55	nazmul	2024-02-16 00:01:35.749345+06	(23.765385,90.365185)	(23.7653663,90.3651877)	{"(23.7653684,90.3651884)"}	f	0	alamgir	t	\N
2569	2024-02-27 15:40:32.849488+06	5	morning	{NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-77-7044	t	ibrahim	nazmul	2024-02-19 15:43:00.107548+06	(23.7626564,90.3702086)	(23.7626678,90.3702102)	{}	f	1	alamgir	t	\N
2570	2024-02-28 16:16:48.537896+06	5	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-77-7044	t	ibrahim	nazmul	2024-02-19 16:18:29.18621+06	(23.7626781,90.3702451)	(23.7659614,90.3649722)	{"(23.7659633,90.3649717)"}	f	1	alamgir	t	\N
1133	2024-01-28 11:06:01.536329+06	6	evening	{"(41,\\"2024-01-28 23:30:00+06\\")","(42,\\"2024-01-28 23:46:00+06\\")","(43,\\"2024-01-28 23:48:00+06\\")","(44,\\"2024-01-28 23:50:00+06\\")","(45,\\"2024-01-28 23:52:00+06\\")","(46,\\"2024-01-28 23:54:00+06\\")","(47,\\"2024-01-28 23:56:00+06\\")","(48,\\"2024-01-28 23:58:00+06\\")","(49,\\"2024-01-28 00:00:00+06\\")","(70,\\"2024-01-28 00:02:00+06\\")"}	from_buet	Ba-17-2081	t	arif43	nazmul	2024-01-28 11:47:17.242132+06	(23.7284663,90.385963)	(23.7626902,90.3702105)	{"(23.72896666,90.38572278)","(23.73013902,90.3858085)","(23.73133374,90.38525864)","(23.73228998,90.38525799)","(23.73345972,90.38499298)","(23.73433992,90.38448765)","(23.73529561,90.38428382)","(23.73645817,90.38395122)","(23.73757092,90.38385736)","(23.73845939,90.38358146)","(23.7393573,90.38324932)","(23.74023132,90.38297697)","(23.74118056,90.38277456)","(23.74219873,90.38249032)","(23.74327511,90.38224412)","(23.74426002,90.38203039)","(23.74584715,90.3814472)","(23.74677089,90.38103901)","(23.74814029,90.3802901)","(23.74922168,90.37977198)","(23.7506087,90.37874385)","(23.75136046,90.37812954)","(23.75348352,90.37678021)","(23.75473408,90.37604626)","(23.75551876,90.37549925)","(23.75640003,90.37514729)","(23.75728416,90.37467067)","(23.75820697,90.37434126)","(23.75890593,90.3735953)","(23.75976808,90.37309223)","(23.76136498,90.37218037)","(23.76163291,90.37113577)","(23.76246582,90.37069227)","(23.76218281,90.36974614)"}	f	0	abdulbari4	t	\N
1456	2024-01-28 17:53:36.383554+06	2	afternoon	{"(12,\\"2024-01-29 19:40:00+06\\")","(13,\\"2024-01-29 19:52:00+06\\")","(14,\\"2024-01-29 19:54:00+06\\")","(15,\\"2024-01-29 19:57:00+06\\")","(16,\\"2024-01-29 20:00:00+06\\")","(70,\\"2024-01-29 20:03:00+06\\")"}	from_buet	Ba-19-0569	t	altaf	mashroor	2024-01-28 17:56:31.342259+06	(23.7326599,90.3851097)	(23.7279021,90.3891548)	{"(23.732575,90.3851479)","(23.7325197,90.3861528)","(23.7325197,90.3861528)","(23.7325599,90.3871496)","(23.7325599,90.3871496)","(23.7316105,90.3869601)","(23.7316105,90.3869601)","(23.7305366,90.387193)","(23.7305366,90.387193)","(23.7296208,90.3876182)","(23.7296208,90.3876182)","(23.728753,90.3883114)","(23.728753,90.3883114)","(23.7279679,90.3890902)","(23.7279679,90.3890902)"}	f	0	ASADUZZAMAN	t	\N
1455	2024-01-28 19:18:40.65915+06	2	morning	{"(12,\\"2024-01-29 12:55:00+06\\")","(13,\\"2024-01-29 12:57:00+06\\")","(14,\\"2024-01-29 12:59:00+06\\")","(15,\\"2024-01-29 13:01:00+06\\")","(16,\\"2024-01-29 13:03:00+06\\")","(70,\\"2024-01-29 13:15:00+06\\")"}	to_buet	Ba-19-0569	t	altaf	mashroor	2024-01-28 19:21:30.530991+06	(23.7276,90.3917)	(23.8743234,90.3888165)	{"(23.7275558,90.3917032)","(23.87425,90.3848517)","(23.8742717,90.3859748)","(23.8742865,90.3871164)","(23.8743101,90.3882773)"}	f	0	ASADUZZAMAN	t	\N
1539	2024-01-28 23:09:32.395969+06	2	evening	{"(12,\\"2024-01-29 23:30:00+06\\")","(13,\\"2024-01-29 23:42:00+06\\")","(14,\\"2024-01-29 23:45:00+06\\")","(15,\\"2024-01-29 23:48:00+06\\")","(16,\\"2024-01-29 23:51:00+06\\")","(70,\\"2024-01-29 23:54:00+06\\")"}	from_buet	Ba-69-8288	t	sohel55	\N	2024-01-28 23:11:44.565029+06	(23.7626813,90.3702191)	(23.7626943,90.3702246)	{}	f	0	mahbub777	t	\N
1667	2024-01-29 13:25:44.736076+06	8	afternoon	{"(64,\\"2024-01-29 19:40:00+06\\")","(65,\\"2024-01-29 19:55:00+06\\")","(66,\\"2024-01-29 19:58:00+06\\")","(67,\\"2024-01-29 20:01:00+06\\")","(68,\\"2024-01-29 20:04:00+06\\")","(69,\\"2024-01-29 20:07:00+06\\")","(70,\\"2024-01-29 20:10:00+06\\")"}	from_buet	Ba-93-6087	t	altaf	\N	2024-01-29 14:12:37.207573+06	(23.7266832,90.3879756)	(37.3307017,-122.0416992)	{"(37.421998333333335,-122.084)","(37.412275,-122.08192166666667)","(37.41010333333333,-122.07694333333333)","(37.40792166666667,-122.06673)","(37.403758333333336,-122.05173833333333)","(37.399258333333336,-122.03277)","(37.399258333333336,-122.03277)","(37.39700166666667,-122.01190166666666)","(37.33032,-122.04479)","(37.33071833333333,-122.04375166666667)","(37.33071,-122.04258)"}	f	0	siddiq2	t	\N
1786	2024-01-29 15:08:16.186189+06	4	morning	{"(27,\\"2024-01-29 12:40:00+06\\")","(28,\\"2024-01-29 12:42:00+06\\")","(29,\\"2024-01-29 12:44:00+06\\")","(30,\\"2024-01-29 12:46:00+06\\")","(31,\\"2024-01-29 12:50:00+06\\")","(32,\\"2024-01-29 12:52:00+06\\")","(33,\\"2024-01-29 12:54:00+06\\")","(34,\\"2024-01-29 12:58:00+06\\")","(35,\\"2024-01-29 13:00:00+06\\")","(70,\\"2024-01-29 13:10:00+06\\")"}	to_buet	BA-01-2345	t	altaf	reyazul	2024-01-29 15:14:46.6046+06	(23.7267164,90.3881888)	(23.7647567,90.360895)	{"(23.764756666666667,90.360895)","(23.764756666666667,90.360895)","(23.764756666666667,90.360895)"}	f	0	alamgir	t	\N
1787	2024-01-29 15:14:51.580955+06	4	afternoon	{"(27,\\"2024-01-29 19:40:00+06\\")","(28,\\"2024-01-29 19:50:00+06\\")","(29,\\"2024-01-29 19:52:00+06\\")","(30,\\"2024-01-29 19:54:00+06\\")","(31,\\"2024-01-29 19:56:00+06\\")","(32,\\"2024-01-29 19:58:00+06\\")","(33,\\"2024-01-29 20:00:00+06\\")","(34,\\"2024-01-29 20:02:00+06\\")","(35,\\"2024-01-29 20:04:00+06\\")","(70,\\"2024-01-29 20:06:00+06\\")"}	from_buet	BA-01-2345	t	altaf	reyazul	2024-01-29 23:18:22.158268+06	(23.7647567,90.360895)	(23.7625974,90.3701842)	{"(23.76468,90.36215)","(23.76468,90.36215)","(23.76468,90.36215)","(23.764895,90.36317)","(23.764895,90.36317)","(23.764895,90.36317)","(23.765118333333334,90.36412833333333)","(23.765118333333334,90.36412833333333)","(23.765118333333334,90.36412833333333)","(23.764333333333333,90.36475666666666)","(23.764333333333333,90.36475666666666)","(23.764333333333333,90.36475666666666)","(23.76392,90.36567833333334)","(23.76392,90.36567833333334)","(23.76392,90.36567833333334)","(23.763133333333332,90.36701166666667)","(23.763133333333332,90.36701166666667)","(23.763133333333332,90.36701166666667)","(23.763403333333333,90.36802833333333)","(23.763403333333333,90.36802833333333)","(23.763403333333333,90.36802833333333)"}	f	0	alamgir	t	\N
1939	2024-01-30 00:56:29.07057+06	7	morning	{"(50,\\"2024-01-30 12:40:00+06\\")","(51,\\"2024-01-30 12:42:00+06\\")","(52,\\"2024-01-30 12:43:00+06\\")","(53,\\"2024-01-30 12:46:00+06\\")","(54,\\"2024-01-30 12:47:00+06\\")","(55,\\"2024-01-30 12:48:00+06\\")","(56,\\"2024-01-30 12:50:00+06\\")","(57,\\"2024-01-30 12:52:00+06\\")","(58,\\"2024-01-30 12:53:00+06\\")","(59,\\"2024-01-30 12:54:00+06\\")","(60,\\"2024-01-30 12:56:00+06\\")","(61,\\"2024-01-30 12:58:00+06\\")","(62,\\"2024-01-30 13:00:00+06\\")","(63,\\"2024-01-30 13:02:00+06\\")","(70,\\"2024-01-30 13:00:00+06\\")"}	to_buet	Ba-46-1334	t	sohel55	\N	2024-01-30 02:00:17.416698+06	(23.7626292,90.3702478)	(23.7626699,90.3702059)	{"(23.874325,90.3888517)","(23.8743526,90.3901666)","(23.874255,90.3850317)","(23.874285,90.3870576)","(23.8743099,90.3882428)","(23.8743416,90.3893562)","(23.8743567,90.3905061)","(23.87438,90.3915867)","(23.87439,90.3926017)","(23.8744091,90.3937183)","(23.8744506,90.3949697)","(23.8745025,90.3961401)","(23.8745545,90.3973035)","(23.8746112,90.3984493)","(23.87462,90.3995454)","(23.87466,90.4006463)","(23.8735066,90.4007136)","(37.4226711,-122.0849872)","(23.7583291,90.3786724)","(23.8742593,90.3851502)","(23.8742757,90.3862376)","(23.8742901,90.3873217)","(23.8743101,90.3883149)","(23.8743435,90.3894298)","(23.874407,90.3937895)","(23.8744109,90.3940086)","(23.8744577,90.3950737)","(23.8745055,90.3961643)","(23.8745501,90.3971665)","(23.87462,90.399455)"}	f	0	nasir81	t	\N
1940	2024-01-30 18:42:57.389505+06	7	afternoon	{"(50,\\"2024-01-30 19:40:00+06\\")","(51,\\"2024-01-30 19:48:00+06\\")","(52,\\"2024-01-30 19:50:00+06\\")","(53,\\"2024-01-30 19:52:00+06\\")","(54,\\"2024-01-30 19:54:00+06\\")","(55,\\"2024-01-30 19:56:00+06\\")","(56,\\"2024-01-30 19:58:00+06\\")","(57,\\"2024-01-30 20:00:00+06\\")","(58,\\"2024-01-30 20:02:00+06\\")","(59,\\"2024-01-30 20:04:00+06\\")","(60,\\"2024-01-30 20:06:00+06\\")","(61,\\"2024-01-30 20:08:00+06\\")","(62,\\"2024-01-30 20:10:00+06\\")","(63,\\"2024-01-30 20:12:00+06\\")","(70,\\"2024-01-30 20:14:00+06\\")"}	from_buet	Ba-46-1334	t	sohel55	\N	2024-01-30 18:50:36.374076+06	(23.7664933,90.3647317)	(23.7664916,90.3647319)	{"(23.7664083,90.364746)"}	f	0	nasir81	t	\N
1992	2024-01-30 19:09:14.244506+06	1	evening	{"(1,\\"2024-02-05 23:30:00+06\\")","(2,\\"2024-02-05 23:37:00+06\\")","(3,\\"2024-02-05 23:40:00+06\\")","(4,\\"2024-02-05 23:42:00+06\\")","(5,\\"2024-02-05 23:44:00+06\\")","(6,\\"2024-02-05 23:56:00+06\\")","(7,\\"2024-02-05 23:59:00+06\\")","(8,\\"2024-02-05 00:02:00+06\\")","(9,\\"2024-02-05 00:05:00+06\\")","(10,\\"2024-02-05 00:08:00+06\\")","(11,\\"2024-02-05 00:11:00+06\\")","(70,\\"2024-02-05 00:14:00+06\\")"}	from_buet	Ba-19-0569	t	altaf	nazmul	2024-01-30 20:12:21.131647+06	(23.7663984,90.3647428)	(23.7666283,90.3646967)	{"(23.7633199,90.3621187)","(23.7664933,90.3647317)","(23.7660378,90.3649393)","(23.7655868,90.3651079)","(23.7647904,90.3653949)","(23.7643363,90.3655313)","(23.7641401,90.3650102)","(23.7639583,90.3643684)","(23.7637966,90.3637644)","(23.7635315,90.3628686)","(23.7631418,90.3615597)","(23.7628039,90.3603286)","(23.7624547,90.3591464)","(23.7619579,90.3588889)","(23.7666283,90.3646967)"}	f	0	siddiq2	t	\N
1933	2024-01-31 02:06:44.0287+06	5	morning	{"(36,\\"2024-01-31 02:24:22.106+06\\")","(37,\\"2024-01-31 02:25:56.057+06\\")","(38,\\"2024-01-31 02:26:57.571+06\\")","(39,\\"2024-01-31 02:28:00.589+06\\")","(40,\\"2024-01-31 02:29:33.261+06\\")","(70,\\"2024-01-31 02:32:09.752+06\\")"}	to_buet	Ba-77-7044	t	rashed3	\N	2024-01-31 02:32:26.830395+06	(23.7660883,90.364925)	(23.7275268,90.3917003)	{"(23.7649583,90.36534)","(23.7642127,90.3653061)","(23.763966,90.3644196)","(23.7635667,90.3629833)","(23.7631566,90.3616)","(23.7626922,90.3599427)","(23.7619673,90.3588807)","(23.7606257,90.3588821)","(23.7594134,90.3591298)","(23.7582786,90.3597956)","(23.757416,90.3606085)","(23.7567556,90.3619079)","(23.7553636,90.3635747)","(23.7540429,90.3651788)","(23.7528579,90.3665731)","(23.751739,90.3676538)","(23.7506441,90.3684183)","(23.7496062,90.3691326)","(23.7485527,90.3698621)","(23.7475619,90.3705334)","(23.7464753,90.3712699)","(23.7454449,90.3719636)","(23.7445081,90.3725616)","(23.7434362,90.3732948)","(23.7424289,90.3739508)","(23.7414579,90.374452)","(23.7402636,90.375049)","(23.7391591,90.3756102)","(23.7382941,90.3762665)","(23.738683,90.3756855)","(23.7395038,90.3753022)","(23.7384414,90.3760868)","(23.7385189,90.3774315)","(23.7388197,90.3793567)","(23.7398813,90.3807054)","(23.7404818,90.3823661)","(23.7397015,90.383306)","(23.738315,90.3836105)","(23.7366835,90.3840001)","(23.7351339,90.38438)","(23.7333583,90.3848333)","(23.7324607,90.3857894)","(23.7321584,90.3870136)","(23.72971,90.38755)","(23.7277783,90.38928)","(23.7277284,90.3907508)","(23.7276,90.3917054)"}	f	0	reyazul	t	\N
1930	2024-01-31 15:14:10.296909+06	4	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-83-8014	t	rafiqul	\N	2024-01-31 15:30:54.236178+06	(23.7267071,90.3880359)	(23.7267111,90.3881077)	{"(23.7267133,90.3880396)"}	f	0	mahmud64	t	\N
1924	2024-01-31 16:58:29.913838+06	2	morning	{NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-22-4326	t	rafiqul	\N	2024-01-31 16:59:59.175579+06	(23.7481383,90.3800983)	(23.7407144,90.3830852)	{"(23.747948333333333,90.38021)","(23.74714,90.38071)","(23.746336666666668,90.381165)","(23.745058333333333,90.381905)","(23.743881666666667,90.38228333333333)","(23.74266,90.38259)","(23.741388333333333,90.38290666666667)"}	f	0	jamal7898	t	\N
1931	2024-01-31 17:11:19.993161+06	4	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-01-31 17:12:07.136+06\\")"}	from_buet	Ba-83-8014	t	rafiqul	\N	2024-01-31 18:17:20.504623+06	(23.7272617,90.3894852)	(23.7648684,90.362928)	{"(23.72742424,90.38952306)","(23.72723315,90.39084778)","(23.72747979,90.38972707)","(23.72839502,90.38905589)","(23.72916022,90.38816033)","(23.73006908,90.38765401)","(23.73106458,90.38708456)","(23.73211297,90.38693844)","(23.73249312,90.385646)","(23.7333372,90.38489895)","(23.73433357,90.38466604)","(23.73523457,90.38425773)","(23.73648617,90.38403921)","(23.73740914,90.38378537)","(23.73833805,90.383601)","(23.73927028,90.38336656)","(23.73933127,90.38230218)","(23.73923418,90.3812476)","(23.73898232,90.38030386)","(23.73867508,90.37932409)","(23.73852853,90.37829491)","(23.73842503,90.37716909)","(23.73863024,90.37590965)","(23.73962306,90.37550073)","(23.74075863,90.37480071)","(23.74194087,90.37422286)","(23.74288106,90.37367614)","(23.74389185,90.37306376)","(23.74489102,90.37226392)","(23.74580263,90.37164569)","(23.74726573,90.3705733)","(23.74833498,90.36976167)","(23.7496622,90.36912699)","(23.75073574,90.36829627)","(23.75153495,90.36777138)","(23.75268138,90.36688452)","(23.75353426,90.36601961)","(23.75420882,90.36514768)","(23.75499203,90.3641664)","(23.75595636,90.36437693)","(23.7568904,90.36415729)","(23.75786953,90.36380382)","(23.75873282,90.36409829)","(23.75962336,90.36386946)","(23.76049656,90.36351761)","(23.76140771,90.36332804)","(23.76227281,90.36301732)","(23.76314569,90.36273093)","(23.76394367,90.36323979)","(23.76479898,90.36290691)"}	f	0	mahmud64	t	\N
1100	2024-01-28 00:31:14.828099+06	3	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-35-1461	t	altaf	nazmul	2024-02-01 19:32:48.812563+06	(23.7623975,90.3646323)	(23.7728898,90.3607467)	{"(23.77292266,90.36075484)","(23.77292266,90.36075484)","(23.77292266,90.36075484)"}	f	0	rashid56	t	\N
1132	2024-01-28 09:15:49.433306+06	6	afternoon	{"(41,\\"2024-01-28 19:40:00+06\\")","(42,\\"2024-01-28 19:56:00+06\\")","(43,\\"2024-01-28 19:58:00+06\\")","(44,\\"2024-01-28 20:00:00+06\\")","(45,\\"2024-01-28 20:02:00+06\\")","(46,\\"2024-01-28 20:04:00+06\\")","(47,\\"2024-01-28 20:06:00+06\\")","(48,\\"2024-01-28 20:08:00+06\\")","(49,\\"2024-01-28 20:10:00+06\\")","(70,\\"2024-01-28 20:12:00+06\\")"}	from_buet	Ba-17-2081	t	arif43	nazmul	2024-01-28 09:45:07.738489+06	(23.7266771,90.388158)	(23.7266784,90.3882818)	{"(23.72655019,90.38848189)","(23.72696112,90.38936913)","(23.72772774,90.39008871)","(23.72809878,90.39110518)","(23.72839477,90.39223458)","(23.72816985,90.39335134)","(23.72780276,90.39453776)","(23.7280286,90.39549392)","(23.72893826,90.39536566)","(23.72997105,90.39542245)","(23.73100256,90.39525183)","(23.73012462,90.39548402)","(23.7290751,90.39542807)","(23.72809697,90.39529247)","(23.72718984,90.39528533)","(23.7267802,90.39425865)","(23.72692749,90.39319299)","(23.72710812,90.39220914)","(23.72732432,90.39121605)","(23.72756128,90.39025052)","(23.72692572,90.3894264)"}	f	0	abdulbari4	t	\N
1932	2024-02-01 20:55:09.481758+06	4	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-02 12:47:22.689+06\\")"}	from_buet	Ba-83-8014	t	rafiqul	\N	2024-02-02 12:49:47.706461+06	(23.7629733,90.3703847)	(23.7275682,90.3917004)	{"(23.7276,90.3917)","(23.7275682,90.3917004)"}	f	0	mahmud64	t	\N
2171	2024-02-12 00:18:32.91871+06	4	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-85-4722	t	rafiqul	nazmul	2024-02-12 02:19:09.925644+06	(23.7626246,90.3701654)	(23.7626582,90.3702212)	{}	f	17	zahir53	t	\N
2221	2024-02-18 10:28:33.023756+06	5	morning	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:28:37.958+06\\")"}	to_buet	Ba-35-1461	t	ibrahim	nazmul	2024-02-09 10:43:54.057066+06	(23.7276,90.3917)	(23.7275679,90.3917004)	{"(23.7275743,90.3917007)"}	f	65	mahabhu	t	\N
2547	2024-02-27 00:06:59.82607+06	5	evening	{"(36,\\"2024-02-16 00:07:04.656+06\\")",NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-36-1921	t	sohel55	nazmul	2024-02-16 00:07:55.93608+06	(23.765385,90.365185)	(23.7653674,90.3651873)	{"(23.7653684,90.3651884)"}	f	0	alamgir	t	\N
2371	2024-02-12 02:45:38.274431+06	5	morning	{"(36,\\"2024-02-12 02:47:07.304+06\\")","(37,\\"2024-02-12 02:54:06.397+06\\")","(38,\\"2024-02-12 03:03:19.762+06\\")","(39,\\"2024-02-12 03:04:53.753+06\\")","(40,\\"2024-02-12 03:06:16.893+06\\")","(70,\\"2024-02-12 03:13:25.199+06\\")"}	to_buet	Ba-83-8014	t	ibrahim	\N	2024-02-12 03:13:38.231164+06	(23.766005,90.3649567)	(23.7280381,90.3916741)	{"(23.7657653,90.3650492)","(23.7649146,90.3653535)","(23.7642239,90.3653657)","(23.7640729,90.3647768)","(23.7638933,90.3641336)","(23.7637269,90.3635254)","(23.7635485,90.3629205)","(23.7633683,90.3622961)","(23.7631896,90.3617172)","(23.76301,90.3611038)","(23.7628502,90.3605077)","(23.7626821,90.3599108)","(23.7625097,90.3593166)","(23.762232,90.358855)","(23.7616996,90.358905)","(23.7611746,90.3589304)","(23.7606726,90.3589029)","(23.7601685,90.358908)","(23.7596515,90.3590269)","(23.7591879,90.3592406)","(23.7587294,90.3594899)","(23.7583015,90.3597836)","(23.7578683,90.3601317)","(23.7574823,90.360544)","(23.7571251,90.360933)","(23.7570414,90.3615042)","(23.7565813,90.3621507)","(23.7560607,90.3627416)","(23.7555116,90.3633934)","(23.7549368,90.3640866)","(23.7544267,90.3647234)","(23.753867,90.3653832)","(23.7532865,90.3660537)","(23.7527253,90.3667216)","(23.7664233,90.3647783)","(23.7655967,90.3651105)","(23.764751,90.3654082)","(23.764293,90.3655487)","(23.7641108,90.3649228)","(23.7639417,90.36431)","(23.7637799,90.3637)","(23.763598,90.3630927)","(23.7632272,90.3618376)","(23.7629598,90.3609264)","(23.7626996,90.3599666)","(23.7624368,90.3590885)","(23.7618254,90.3588738)","(23.7610036,90.3589258)","(23.7602393,90.3589026)","(23.7595201,90.3590784)","(23.7587854,90.3594542)","(23.7581484,90.3599091)","(23.7576776,90.3603406)","(23.7573414,90.3606809)","(23.7571076,90.3611113)","(23.7568605,90.3617725)","(23.7563149,90.3624542)","(23.7554914,90.36342)","(23.7543145,90.3648641)","(23.7531105,90.3662673)","(23.7519853,90.36746)","(23.7513449,90.3679348)","(23.7507078,90.3683713)","(23.7500552,90.3688201)","(23.7493448,90.3693134)","(23.748652,90.3697949)","(23.747973,90.3702554)","(23.7472964,90.3707102)","(23.7466068,90.3711799)","(23.7459387,90.3716308)","(23.7452157,90.3721172)","(23.7445494,90.3725405)","(23.7438476,90.373011)","(23.7431563,90.3734867)","(23.7425079,90.3739108)","(23.7417728,90.3742691)","(23.7409673,90.3746959)","(23.7402595,90.3750506)","(23.739522,90.3754201)","(23.7388582,90.3757706)","(23.7383228,90.3762681)","(23.7390132,90.3755614)","(23.7395395,90.3752892)","(23.7391111,90.3756351)","(23.738437,90.376088)","(23.7384598,90.3769067)","(23.7386033,90.3779728)","(23.7387189,90.3788569)","(23.7389093,90.3798093)","(23.7391099,90.3808644)","(23.7397484,90.3807831)","(23.7402156,90.3810192)","(23.7403622,90.3818173)","(23.7404987,90.3825575)","(23.7404604,90.3831625)","(23.7398012,90.3832774)","(23.739203,90.3834002)","(23.7385211,90.3835447)","(23.7379241,90.3837295)","(23.7372499,90.383885)","(23.7365905,90.3840186)","(23.7359729,90.384155)","(23.7353731,90.384315)","(23.7346782,90.3845029)","(23.7340316,90.3846505)","(23.7333872,90.3848247)","(23.7327701,90.3850115)","(23.7324771,90.3855497)","(23.73253,90.3862503)","(23.7326294,90.3869497)","(23.7320638,90.3870605)","(23.7309049,90.3870808)","(23.7298908,90.3874564)","(23.7290554,90.3880383)","(23.7282312,90.3888271)","(23.7275208,90.3895944)","(23.72766,90.3905771)","(23.7280381,90.3916741)"}	f	0	alamgir	t	\N
2009	2024-02-02 15:42:11.283236+06	6	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-02 16:15:01.019+06\\")"}	from_buet	Ba-35-1461	t	rafiqul	\N	2024-02-02 16:27:07.931376+06	(23.7276,90.3917)	(23.7275838,90.3917005)	{"(23.7648733,90.3653667)","(23.7645031,90.3654853)","(23.7641497,90.3650402)","(23.7639833,90.3644567)","(23.7638116,90.3638234)","(23.7636397,90.3632387)","(23.7634616,90.3626133)","(23.7632783,90.362005)","(23.7630968,90.3613995)","(23.76241,90.3590017)","(23.7617215,90.3589035)","(23.7612486,90.3589302)","(23.7606,90.35889)","(23.7585283,90.3596133)","(23.7580886,90.3599568)","(23.7552767,90.363675)","(23.7549367,90.3640867)","(23.7544,90.364755)","(23.7538401,90.3654132)","(23.7532599,90.3660852)","(23.7527252,90.3667217)","(23.7521438,90.3673408)","(23.7514803,90.367835)","(23.7507733,90.368325)","(23.7500894,90.368798)","(23.7493783,90.3692901)","(23.748685,90.3697718)","(23.7479735,90.370255)","(23.747265,90.3707333)","(23.7465733,90.3712017)","(23.745873,90.3716733)","(23.74518,90.3721417)","(23.7445134,90.3725567)","(23.7438169,90.3730334)","(23.7431234,90.3735101)","(23.7424302,90.3739502)","(23.7416697,90.3743279)","(23.7409301,90.3747134)","(23.7401884,90.3750834)","(23.7394514,90.3754565)","(23.7387278,90.3758431)","(23.7382881,90.3762742)","(23.7386099,90.3757791)","(23.7390961,90.3755225)","(23.7395632,90.3752781)","(23.7390285,90.3756786)","(23.7383976,90.3761686)","(23.7384951,90.3771404)","(23.7386264,90.3781189)","(23.7387567,90.3790406)","(23.7388567,90.3795495)","(23.7389501,90.3800361)","(23.7392043,90.3808549)","(23.7398817,90.380695)","(23.7402218,90.3811281)","(23.7403801,90.3819349)","(23.7405283,90.3827098)","(23.74038,90.3831792)","(23.7397053,90.3832883)","(23.7390403,90.3834301)","(23.7383795,90.3835895)","(23.7377132,90.3837803)","(23.7370269,90.3839301)","(23.7363717,90.3840601)","(23.7357267,90.3842167)","(23.7350732,90.3843967)","(23.734415,90.3845635)","(23.733788,90.3847131)","(23.7331683,90.3848867)","(23.7326061,90.3851288)","(23.7324705,90.3857902)","(23.732565,90.3864833)","(23.7325621,90.3871518)","(23.7316117,90.3869603)","(23.7310527,90.3870348)","(23.7305355,90.3871928)","(23.7300948,90.3873619)","(23.7296008,90.3876295)","(23.7291602,90.3879549)","(23.7287433,90.3883199)","(23.7283532,90.388695)","(23.7279634,90.3890949)","(23.7276243,90.389439)","(23.7275883,90.3902752)","(23.7277466,90.3907988)","(23.7279398,90.3913367)","(23.7275878,90.3917004)"}	f	0	alamgir	t	\N
2621	2024-03-02 20:15:53.088148+06	6	afternoon	{NULL,"(42,\\"2024-02-20 20:15:58.864+06\\")","(43,\\"2024-02-20 20:21:26.506+06\\")","(44,\\"2024-02-20 20:22:35.984+06\\")","(45,\\"2024-02-20 20:23:46.549+06\\")","(46,\\"2024-02-20 20:25:36.748+06\\")","(47,\\"2024-02-20 20:29:57.552+06\\")","(48,\\"2024-02-20 20:31:46.742+06\\")","(49,\\"2024-02-20 20:32:48.944+06\\")",NULL}	from_buet	Ba-20-3066	t	ibrahim	\N	2024-02-20 20:56:11.973364+06	(23.80535,90.3638417)	(23.736082,90.3841223)	{"(23.8054956,90.3640945)","(23.805852,90.3646929)","(23.8055,90.3643254)","(23.8052532,90.3639036)","(23.8049553,90.3633785)","(23.8045951,90.362713)","(23.8042925,90.3622432)","(23.8038483,90.3616015)","(23.8033441,90.3608669)","(23.8030879,90.3604457)","(23.8025996,90.359699)","(23.8021147,90.3589315)","(23.8018541,90.3585239)","(23.8014504,90.3578222)","(23.8011453,90.3573684)","(23.8008768,90.3569655)","(23.8004831,90.3563556)","(23.800122,90.3557834)","(23.7996626,90.3553823)","(23.7994842,90.3547587)","(23.7991213,90.3541983)","(23.7987401,90.3535799)","(23.7983003,90.3533453)","(23.797701,90.3532882)","(23.7971243,90.3533304)","(23.7965448,90.3533866)","(23.7959835,90.3534186)","(23.795441,90.3534581)","(23.7949086,90.3535037)","(23.7943778,90.353552)","(23.7938439,90.3536072)","(23.7933199,90.3536611)","(23.7927831,90.3537106)","(23.7922429,90.3537433)","(23.7917056,90.3537696)","(23.7911733,90.3538221)","(23.7906489,90.3538468)","(23.7901148,90.3538802)","(23.789583,90.3539188)","(23.7890957,90.3539331)","(23.7885484,90.3539401)","(23.7879516,90.3539467)","(23.7873805,90.3539552)","(23.7868478,90.3539837)","(23.7863348,90.3540149)","(23.7858584,90.3540403)","(23.7852775,90.3540352)","(23.7847719,90.3538439)","(23.7843895,90.3535327)","(23.7838788,90.3531733)","(23.7834172,90.3528818)","(23.7829469,90.3525949)","(23.7820365,90.352105)","(23.782462,90.3523137)","(23.7815708,90.3519645)","(23.781268,90.3524448)","(23.7810349,90.3529007)","(23.7807861,90.3533592)","(23.7805486,90.3538112)","(23.7801238,90.3546528)","(23.7798917,90.3551305)","(23.7796622,90.3555788)","(23.7794095,90.3560359)","(23.7791899,90.3565483)","(23.7790291,90.35704)","(23.7790385,90.357545)","(23.778979,90.3580519)","(23.7788968,90.358571)","(23.7788374,90.3590894)","(23.7787356,90.3596097)","(23.7786175,90.3601026)","(23.7783546,90.36053)","(23.7781105,90.3609817)","(23.7778478,90.361421)","(23.7775872,90.3618422)","(23.7773402,90.3622737)","(23.777059,90.3626903)","(23.7767807,90.3631072)","(23.776508,90.3635253)","(23.7762238,90.3639392)","(23.7759286,90.3643543)","(23.775635,90.364764)","(23.7753404,90.3651643)","(23.7750452,90.365545)","(23.7746808,90.3659507)","(23.7743778,90.3663463)","(23.7739453,90.3667216)","(23.773527,90.3670624)","(23.7731307,90.367341)","(23.7726749,90.3675473)","(23.7722082,90.3677187)","(23.7717103,90.3678983)","(23.7712584,90.3680714)","(23.7706334,90.3682947)","(23.7701504,90.3684915)","(23.7697047,90.3686741)","(23.7692544,90.3688518)","(23.7688043,90.3690188)","(23.7683594,90.3692047)","(23.7679068,90.3693854)","(23.7674521,90.3695505)","(23.7669942,90.3697226)","(23.766551,90.3698974)","(23.7660971,90.3700799)","(23.76565,90.370265)","(23.7652034,90.3704484)","(23.7647606,90.3706313)","(23.7642902,90.3707999)","(23.7637895,90.3710044)","(23.763311,90.3712332)","(23.7628761,90.3714747)","(23.7624471,90.371723)","(23.7620008,90.3719732)","(23.7615563,90.3722234)","(23.7611142,90.372483)","(23.760708,90.3727405)","(23.7602205,90.3730244)","(23.7597901,90.3732706)","(23.7593566,90.3735286)","(23.7589171,90.3738114)","(23.7584523,90.3741181)","(23.7580109,90.3744149)","(23.7575771,90.3746169)","(23.7571699,90.374848)","(23.7567592,90.375101)","(23.7563451,90.3753402)","(23.7559013,90.3756007)","(23.755484,90.3758512)","(23.7550501,90.3760985)","(23.7546539,90.3763682)","(23.7542264,90.3766354)","(23.7537956,90.3768473)","(23.7533715,90.3770769)","(23.752949,90.3773203)","(23.752512,90.3775229)","(23.7521006,90.3777752)","(23.7516751,90.3780297)","(23.7512641,90.378269)","(23.750567,90.3786674)","(23.7500691,90.3789627)","(23.7496166,90.3792377)","(23.7491928,90.3794921)","(23.7483807,90.3799546)","(23.7479123,90.3802316)","(23.7474959,90.380481)","(23.7470544,90.3807571)","(23.7466478,90.3809814)","(23.7461946,90.3812457)","(23.7457547,90.3815019)","(23.7453462,90.381745)","(23.7449054,90.3819903)","(23.7441734,90.3822286)","(23.7436609,90.3823353)","(23.7431908,90.3824481)","(23.7427253,90.3825704)","(23.7422631,90.3826834)","(23.7417971,90.3827926)","(23.7413443,90.3829202)","(23.7408766,90.3830487)","(23.7400566,90.3832283)","(23.7395876,90.3833202)","(23.7390714,90.383423)","(23.7385816,90.3835282)","(23.7381338,90.3836642)","(23.7376503,90.3837935)","(23.7371354,90.3839085)","(23.736669,90.3840079)","(23.7361592,90.3841101)","(37.4220936,-122.083922)","(23.7358107,90.3841958)"}	f	0	mahabhu	t	\N
2222	2024-02-18 10:44:04.075992+06	5	afternoon	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:44:08.967+06\\")"}	from_buet	Ba-35-1461	t	ibrahim	nazmul	2024-02-09 10:46:18.534544+06	(23.7275682,90.3917004)	(23.7275686,90.3917004)	{"(23.7275675,90.3917007)"}	f	55	mahabhu	t	\N
2571	2024-02-29 16:19:22.210392+06	5	evening	{"(36,\\"2024-02-19 16:19:54.78+06\\")","(37,\\"2024-02-19 16:24:34.468+06\\")","(38,\\"2024-02-19 16:26:34.855+06\\")","(39,\\"2024-02-19 16:28:07.161+06\\")","(40,\\"2024-02-19 16:29:19.003+06\\")",NULL}	from_buet	Ba-77-7044	t	ibrahim	nazmul	2024-02-19 16:33:26.209373+06	(23.7659633,90.3649717)	(23.7380561,90.3836774)	{"(23.7659633,90.3649717)","(23.7653862,90.3651844)","(23.7648864,90.3653552)","(23.7642452,90.3653919)","(23.7640651,90.3647518)","(23.7638933,90.3641333)","(23.7637302,90.3635359)","(23.7636079,90.3630322)","(23.7634153,90.3623624)","(23.7632335,90.3617868)","(23.763057,90.361188)","(23.7628844,90.360566)","(23.7627219,90.359978)","(23.76255,90.3593733)","(23.7623552,90.3588117)","(23.761758,90.3588995)","(23.7612419,90.3589302)","(23.7607329,90.3589161)","(23.7602126,90.3589003)","(23.7597121,90.3589972)","(23.7592155,90.3592232)","(23.7587685,90.3594626)","(23.7583194,90.3597681)","(23.7579086,90.3600998)","(23.7575348,90.3604878)","(23.7571518,90.3608505)","(23.757038,90.3615345)","(23.7565876,90.362164)","(23.7560149,90.3627994)","(23.755466,90.3634562)","(23.7549248,90.3641119)","(23.7543737,90.3647987)","(23.7538956,90.3653541)","(23.7533141,90.3660272)","(23.7528153,90.3666262)","(23.7521875,90.3673072)","(23.7514941,90.3678157)","(23.7507989,90.368301)","(23.750147,90.3687514)","(23.7494501,90.3692385)","(23.7487839,90.3697045)","(23.7481053,90.3701665)","(23.7474942,90.3705771)","(23.7467729,90.3710668)","(23.7460923,90.3715221)","(23.7453618,90.3720186)","(23.744684,90.3724514)","(23.7439931,90.3729138)","(23.7433111,90.3733829)","(23.7426751,90.3738066)","(23.7419141,90.3741881)","(23.7411097,90.3746231)","(23.7404091,90.3749736)","(23.7396621,90.3753438)","(23.738952,90.3757188)","(23.7384012,90.376189)","(23.7389809,90.3755869)","(23.7394945,90.3753153)","(23.7391341,90.375622)","(23.7384827,90.3760162)","(23.7384683,90.3769085)","(23.7385783,90.3778214)","(23.7387,90.3787597)","(23.7388929,90.3797317)","(23.7390655,90.3806506)","(23.7396737,90.3807481)","(23.7401621,90.3808634)","(23.7403261,90.3816573)","(23.7404705,90.3824003)","(23.740523,90.3831325)","(23.7399246,90.3832497)","(23.739288,90.3833813)","(23.7385847,90.3835279)","(23.7381366,90.3836647)"}	f	0	alamgir	t	\N
1951	2024-02-16 00:13:04.050648+06	3	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-24-8518	t	sohel55	nazmul	2024-02-16 00:13:18.70594+06	(23.7653674,90.3651873)	(23.7653672,90.3651874)	{"(23.7653641,90.3651896)"}	f	0	alamgir	t	\N
2008	2024-02-02 19:40:28.46654+06	6	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-35-1461	t	rafiqul	\N	2024-02-02 22:31:33.411593+06	(23.765635,90.365095)	(23.7653685,90.3651876)	{"(23.7626499,90.3598)","(23.7624735,90.359203)","(23.7619189,90.3588915)","(23.7614065,90.3589234)","(23.7609,90.35893)","(23.7603947,90.3588877)","(23.7599001,90.3589495)","(23.7594148,90.3591332)","(23.758946,90.359368)","(23.7585274,90.3596138)","(23.7580886,90.3599568)","(23.7576788,90.3603374)","(23.7573053,90.3607121)","(23.7571015,90.3611901)","(23.7568606,90.3617874)","(23.7563121,90.3624558)","(23.7557737,90.3630793)","(23.7551984,90.3637684)","(23.7546567,90.3644367)","(23.7541235,90.3650852)","(23.7535467,90.3657518)","(23.7530315,90.3663601)","(23.7524718,90.3670183)","(23.7518234,90.3675801)","(23.7511352,90.3680801)","(23.7504491,90.3685505)","(23.749737,90.3690417)","(23.7490431,90.3695251)","(23.74837,90.3699901)","(23.74766,90.3704667)","(23.7469667,90.3709333)","(23.7462618,90.3714119)","(23.7455777,90.371873)","(23.7448882,90.3723303)","(23.7442149,90.372763)","(23.7434984,90.3732516)","(23.7428323,90.3737038)","(23.7420718,90.3741136)","(23.7413535,90.3745018)","(23.7406181,90.3748701)","(23.7398686,90.3752368)","(23.7391599,90.3756102)","(23.738456,90.3760511)","(23.7388095,90.3756723)","(23.739308,90.3754147)","(23.7397805,90.3752312)","(23.7663067,90.3648533)","(23.7654684,90.3651552)","(23.765385,90.365185)","(23.765385,90.365185)"}	f	0	alamgir	t	\N
2010	2024-02-03 02:00:30.432902+06	6	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-35-1461	t	rafiqul	\N	2024-02-03 02:21:31.972824+06	(23.7654267,90.36517)	(23.7571217,90.3609075)	{"(23.75712,90.36088)"}	f	0	alamgir	t	\N
3738	2024-04-23 15:24:30.728374+06	5	morning	{"(36,\\"2024-04-23 15:25:06.125+06\\")","(37,\\"2024-04-23 15:28:56.022+06\\")","(38,\\"2024-04-23 15:30:09.825+06\\")",NULL,NULL,"(70,\\"2024-04-23 15:39:24.394+06\\")"}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-23 15:40:12.691794+06	(23.7665383,90.364725)	(23.7275962,90.3917001)	{"(23.7665383,90.364725)","(23.7665318,90.3647261)","(23.7660135,90.3649534)","(23.7652105,90.3652598)","(23.764637,90.3654243)","(23.7642134,90.365247)","(23.7640558,90.3647205)","(23.7638826,90.364091)","(23.7637257,90.363522)","(23.7635805,90.3629254)","(23.7633089,90.3620199)","(23.7630422,90.3611271)","(23.7627718,90.3601058)","(23.7625028,90.3592244)","(23.7619384,90.3588815)","(23.7611193,90.3589304)","(23.7603599,90.3588877)","(23.7596395,90.3590203)","(23.7589431,90.359362)","(23.7582911,90.3597886)","(23.7577089,90.3603028)","(23.7571871,90.3608181)","(23.7568549,90.3617846)","(23.7560377,90.3627677)","(23.755312,90.3636318)","(23.7544379,90.364708)","(23.7536077,90.3656815)","(23.7528694,90.3665586)","(23.7519545,90.3674791)","(23.750848,90.3682746)","(23.7267299,90.3884703)","(23.75084,90.36828)","(23.7273787,90.3917032)"}	f	1	rashid56	t	{"2024-04-23 15:29:17.761+06","2024-04-23 15:29:27.902+06","2024-04-23 15:29:38.282+06","2024-04-23 15:29:48.618+06","2024-04-23 15:29:59.024+06","2024-04-23 15:30:09.826+06","2024-04-23 15:30:20.326+06","2024-04-23 15:30:48.807+06","2024-04-23 15:39:14.401+06","2024-04-23 15:39:24.394+06"}
3762	2024-04-24 15:04:22.350952+06	5	morning	{NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-25 13:12:50.66137+06	(23.8319151,90.3530802)	(23.7671967,90.3644957)	{"(23.8319151,90.3530802)","(23.8319249,90.353084)","(23.8319099,90.3530927)","(23.8319774,90.3537097)","(23.8319144,90.3547828)","(23.8313127,90.3552585)","(23.8309178,90.3548831)","(23.8302981,90.3574199)","(23.830121,90.3581619)","(23.8294291,90.3590721)","(23.8282951,90.3591106)","(23.8284399,90.3597579)","(23.8284863,90.3602588)","(23.8285134,90.3611332)","(23.8282511,90.3615665)","(23.8276808,90.3616357)","(23.8274345,90.3621915)","(23.8274076,90.3627064)","(23.8272891,90.3621332)","(23.8276208,90.3616579)","(23.8283144,90.3610154)","(23.8283799,90.3603078)","(23.8283249,90.3590726)","(23.8293222,90.3591398)","(23.8300122,90.3590466)","(23.830171,90.3581986)","(23.8303384,90.3574201)","(23.8304892,90.3565701)","(23.8306457,90.3557336)","(23.8311143,90.3553184)","(23.8315766,90.3552051)","(23.831941,90.3549049)","(23.8319396,90.3544117)","(23.8319571,90.3539201)","(23.8319426,90.3534244)","(23.8313459,90.3534584)","(23.8319075,90.3531049)","(23.8311383,90.3535092)","(23.8319103,90.3531033)","(37.4220936,-122.083922)","(23.7673946,90.3644158)"}	f	2	rashid56	t	{"2024-04-24 16:50:33.778+06","2024-04-24 16:50:58.743+06","2024-04-24 16:51:10.615+06","2024-04-24 16:51:26.713+06","2024-04-24 20:39:02.832+06","2024-04-24 20:39:31.23+06","2024-04-24 20:50:40.119+06","2024-04-24 20:50:52.525+06","2024-04-25 13:12:38.06+06","2024-04-25 13:12:47.919+06"}
3884	2024-04-25 13:19:48.174714+06	5	morning	{"(36,\\"2024-04-25 13:20:03.61+06\\")","(37,\\"2024-04-25 13:28:09.642+06\\")","(38,\\"2024-04-25 13:31:39.647+06\\")","(39,\\"2024-04-25 13:34:59.679+06\\")","(40,\\"2024-04-25 13:37:29.703+06\\")",NULL}	to_buet	Ba-24-8518	t	nizam88	\N	2024-04-25 13:41:46.395007+06	(23.76551,90.36514)	(23.7387285,90.378891)	{"(23.76551,90.36514)","(23.7654861,90.3651489)","(23.7648731,90.3653669)","(23.764288,90.3655483)","(23.7641485,90.3650407)","(23.7639667,90.3643984)","(23.7638033,90.3637951)","(23.7636228,90.3631791)","(23.7634441,90.3625696)","(23.7632808,90.3620153)","(23.7631172,90.3614661)","(23.7629357,90.3608505)","(23.7627877,90.3602648)","(23.7626129,90.3596864)","(23.7624445,90.3591127)","(23.7619438,90.3588892)","(23.7614065,90.3589234)","(23.7609001,90.3589301)","(23.7603948,90.3588879)","(23.7599002,90.3589494)","(23.7594147,90.3591329)","(23.7589642,90.3593491)","(23.7585417,90.3596018)","(23.7581392,90.3599201)","(23.7577345,90.3602378)","(23.7573992,90.3606321)","(23.7571175,90.3610271)","(23.7569944,90.3616137)","(23.7565808,90.3621501)","(23.7562546,90.3625231)","(23.7557742,90.3630786)","(23.7554687,90.3634468)","(23.7549369,90.3640865)","(23.7544383,90.3647118)","(23.7540972,90.3651167)","(23.7536358,90.3656522)","(23.7532599,90.3660852)","(23.7528585,90.3665693)","(23.7524452,90.3670482)","(23.7520128,90.3674474)","(23.7514805,90.3678348)","(23.7510296,90.3681528)","(23.7504488,90.3685507)","(23.7500499,90.3688259)","(23.7494102,90.3692684)","(23.7487521,90.3697258)","(23.7480668,90.3702027)","(23.747424,90.370625)","(23.7470002,90.37091)","(23.7464368,90.3712991)","(23.7460186,90.3715717)","(23.7454512,90.3719619)","(23.7449564,90.37229)","(23.7444593,90.3725942)","(23.7439154,90.3729667)","(23.7434609,90.3732765)","(23.7428988,90.3736607)","(23.7424734,90.3739305)","(23.7417718,90.3742682)","(23.7410371,90.3746602)","(23.7404013,90.3749723)","(23.7399409,90.3752019)","(23.739306,90.3755373)","(23.7388602,90.3757705)","(23.738334,90.3761548)","(23.7386248,90.375761)","(23.7391134,90.3755126)","(23.7395822,90.375268)","(23.7390553,90.3756654)","(23.7384281,90.3760904)","(23.7384162,90.3765928)","(23.7385328,90.3774376)","(23.7385845,90.3779356)","(23.7386706,90.3784555)","(23.7387373,90.3789412)"}	f	0	rashid56	t	{"2024-04-25 13:38:59.682+06","2024-04-25 13:39:19.698+06","2024-04-25 13:39:39.7+06","2024-04-25 13:40:18.102+06","2024-04-25 13:40:44.809+06","2024-04-25 13:40:49.585+06","2024-04-25 13:41:09.737+06","2024-04-25 13:41:19.726+06","2024-04-25 13:41:31.539+06","2024-04-25 13:41:41.592+06"}
3810	2024-04-25 13:54:05.411629+06	5	morning	{"(36,\\"2024-04-25 13:54:31.067+06\\")",NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-25 13:57:39.637991+06	(23.7660883,90.364925)	(23.7628796,90.3606201)	{"(23.7660883,90.364925)","(23.7660669,90.3649334)","(23.7656222,90.3651115)","(23.7649996,90.3653266)","(23.764418,90.3655117)","(23.7641439,90.3650278)","(23.7640004,90.3645184)","(23.7638267,90.3638835)","(23.7636555,90.3632939)","(23.7634791,90.3626859)","(23.7633161,90.3621246)","(23.7631352,90.3615439)","(23.7629672,90.3609602)"}	f	0	rashid56	t	{"2024-04-25 13:54:31.068+06","2024-04-25 13:54:46.79+06","2024-04-25 13:55:06.787+06","2024-04-25 13:55:23.561+06","2024-04-25 13:55:45.075+06","2024-04-25 13:56:05.575+06","2024-04-25 13:56:26.812+06","2024-04-25 13:56:46.823+06","2024-04-25 13:57:06.834+06","2024-04-25 13:57:26.832+06"}
1952	2024-02-16 00:14:28.817928+06	3	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-24-8518	t	sohel55	nazmul	2024-02-16 00:14:56.124775+06	(23.7653674,90.3651873)	(23.7653679,90.3651872)	{"(23.7653669,90.3651875)"}	f	0	alamgir	t	\N
2420	2024-02-14 03:14:08.295162+06	5	morning	{"(36,\\"2024-02-12 03:14:43.351+06\\")",NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-36-1921	t	ibrahim	\N	2024-02-12 03:15:01.775175+06	(23.76614,90.3649067)	(23.7642352,90.365483)	{"(23.7659969,90.3649581)","(23.7655544,90.3651242)","(23.7647096,90.3654216)"}	f	0	mahabhu	t	\N
2223	2024-02-18 10:46:30.002967+06	8	evening	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:46:34.971+06\\")"}	from_buet	Ba-35-1461	t	ibrahim	nazmul	2024-02-09 10:50:58.024208+06	(23.7275684,90.3917004)	(23.7275677,90.3917005)	{"(23.7275675,90.3917007)"}	f	44	mahabhu	t	\N
3834	2024-04-25 14:03:38.979843+06	5	morning	{"(36,\\"2024-04-25 14:04:03.584+06\\")","(37,\\"2024-04-25 14:12:00.428+06\\")","(38,\\"2024-04-25 14:15:56.087+06\\")","(39,\\"2024-04-25 14:18:50.479+06\\")",NULL,NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-25 14:20:57.66891+06	(23.7660467,90.36494)	(23.7417915,90.3742539)	{"(23.7660467,90.36494)","(23.766025,90.3649485)","(23.7655776,90.3651284)","(23.7649995,90.3653267)","(23.7643734,90.365525)","(23.7641356,90.3649958)","(23.7639921,90.3644885)","(23.7638199,90.3638535)","(23.7636496,90.3632683)","(23.7634698,90.362643)","(23.7633018,90.3620781)","(23.763134,90.3615264)","(23.7629541,90.3609143)","(23.7628032,90.3603296)","(23.7626313,90.3597499)","(23.7624741,90.3592027)","(23.7621541,90.3588506)","(23.7616353,90.3589099)","(23.7611507,90.3589309)","(23.7606601,90.3589013)","(23.7601807,90.3589065)","(23.7597008,90.3590074)","(23.7592348,90.3592179)","(23.7587989,90.359444)","(23.7584015,90.3597027)","(23.7579795,90.3600445)","(23.7576371,90.3603879)","(23.7572478,90.3607652)","(23.7570412,90.36145)","(23.7566111,90.3621086)","(23.7560892,90.3627112)","(23.7555383,90.3633618)","(23.7549878,90.3640242)","(23.7544936,90.3646416)","(23.7541771,90.3650232)","(23.7536946,90.3655838)","(23.7533388,90.3659933)","(23.7529106,90.3665058)","(23.7524985,90.3669865)","(23.7521164,90.3673729)","(23.7515453,90.3677882)","(23.7511042,90.368103)","(23.7505118,90.3685066)","(23.75012,90.3687752)","(23.7494435,90.369245)","(23.7488505,90.3696564)","(23.7484576,90.369929)","(23.7478244,90.3703572)","(23.7474301,90.3706216)","(23.7468356,90.3710231)","(23.7464103,90.3713151)","(23.7458448,90.3716827)","(23.7453786,90.3720082)","(23.7449052,90.3723245)","(23.7443452,90.3726729)","(23.7438652,90.3730011)","(23.7432903,90.3733996)","(23.7428747,90.3736768)","(23.7422527,90.3740317)","(23.7417915,90.3742539)"}	f	0	rashid56	t	{"2024-04-25 14:18:32.597+06","2024-04-25 14:18:50.48+06","2024-04-25 14:19:04.089+06","2024-04-25 14:19:20.471+06","2024-04-25 14:19:35.092+06","2024-04-25 14:19:50.481+06","2024-04-25 14:20:07.041+06","2024-04-25 14:20:20.508+06","2024-04-25 14:20:38.093+06","2024-04-25 14:20:57.651+06"}
2029	2024-02-01 23:24:27.841567+06	5	morning	{"(36,\\"2024-02-01 23:43:37.427+06\\")","(37,\\"2024-02-01 23:46:25.051+06\\")","(38,\\"2024-02-01 23:48:20.947+06\\")","(39,\\"2024-02-01 23:49:54.932+06\\")","(40,\\"2024-02-01 23:51:40.719+06\\")","(70,\\"2024-02-01 23:54:27.408+06\\")"}	to_buet	Ba-19-0569	t	rahmatullah	\N	2024-02-01 23:55:36.4686+06	(23.7276,90.3917)	(23.7275675,90.3917005)	{"(23.7643783,90.3655217)","(23.76413,90.3649805)","(23.7639583,90.3643683)","(23.7637883,90.363735)","(23.7636147,90.3631502)","(23.7634398,90.3625299)","(23.7629853,90.3610403)","(23.7625683,90.3595056)","(23.7616309,90.3588977)","(23.7605135,90.3588799)","(23.7591929,90.3592394)","(23.7581483,90.3599098)","(23.7571333,90.3608661)","(23.7570507,90.3613632)","(23.7566131,90.3621009)","(23.7560355,90.3627703)","(23.7554866,90.3634248)","(23.7549367,90.3640867)","(23.7544267,90.3647233)","(23.7539463,90.365291)","(23.7533672,90.3659612)","(23.7528594,90.3665706)","(23.7522403,90.3672697)","(23.7515454,90.3677886)","(23.75084,90.3682802)","(23.7501216,90.368775)","(23.7494749,90.3692234)","(23.7488493,90.3696603)","(23.7481058,90.3701665)","(23.7474939,90.3705771)","(23.7467392,90.3710897)","(23.746062,90.3715418)","(23.7453449,90.3720299)","(23.74467,90.3724602)","(23.7439816,90.3729215)","(23.7433031,90.3733883)","(23.7426694,90.3738104)","(23.7419106,90.3741906)","(23.7411078,90.3746249)","(23.7403366,90.3750101)","(23.7395918,90.3753817)","(23.7388803,90.3757584)","(23.7383764,90.3762794)","(23.7395087,90.3753061)","(23.7388731,90.3757675)","(23.738622,90.3781165)","(23.7389698,90.3801444)","(23.7401989,90.3810349)","(23.7405804,90.3829794)","(23.7392125,90.3834244)","(23.7376194,90.3838019)","(23.7361572,90.3841101)","(23.7345389,90.3845399)","(23.7327824,90.3849899)","(23.7325445,90.38645)","(23.7312018,90.3870402)","(23.72906,90.38804)","(23.7273701,90.389659)","(23.7275433,90.3901345)","(23.7278341,90.3910534)","(23.7277747,90.3916944)"}	f	0	altaf	t	\N
1934	2024-02-09 10:54:05.009695+06	5	afternoon	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:55:00.044+06\\")"}	from_buet	Ba-77-7044	t	rashed3	\N	2024-02-09 10:55:34.394021+06	(23.7276,90.3917)	(23.7275682,90.3917004)	{"(23.7276,90.3917)"}	f	0	reyazul	t	\N
2696	2024-03-04 00:14:44.757809+06	6	morning	{"(41,\\"2024-03-04 00:14:50.529+06\\")","(42,\\"2024-03-04 00:16:50.557+06\\")","(43,\\"2024-03-04 00:26:07.813+06\\")","(44,\\"2024-03-04 00:27:22.196+06\\")","(45,\\"2024-03-04 00:28:03.68+06\\")","(46,\\"2024-03-04 00:28:57.325+06\\")","(47,\\"2024-03-04 00:30:51.657+06\\")","(48,\\"2024-03-04 00:31:33.95+06\\")","(49,\\"2024-03-04 00:31:44.564+06\\")",NULL}	to_buet	Ba-97-6734	t	shahid88	nazmul	2024-03-04 00:36:24.76929+06	(23.8069005,90.3685545)	(23.7391803,90.3833787)	{"(23.8069276,90.3684902)","(23.8068718,90.3678772)","(23.8067201,90.3671254)","(23.8065333,90.3663833)","(23.8062284,90.3656201)","(23.8058738,90.3649754)","(23.8056333,90.3645213)","(23.8052864,90.3639603)","(23.805053,90.3635353)","(23.8047382,90.362954)","(23.8043412,90.3623165)","(23.8039125,90.3616928)","(23.803457,90.3610371)","(23.8031085,90.3604018)","(23.8036049,90.3609648)","(23.8040301,90.36166)","(23.8045167,90.3624)","(23.8048179,90.3628781)","(23.8051543,90.3634973)","(23.8054355,90.3640057)","(23.8058224,90.3646442)","(23.8060803,90.365123)","(23.8056143,90.3645149)","(23.805364,90.364096)","(23.8051083,90.3636392)","(23.8046954,90.3628822)","(23.8044436,90.3624737)","(23.8041761,90.3620736)","(23.8036652,90.3613486)","(23.8031799,90.3605954)","(23.8028414,90.3600869)","(23.802444,90.3594513)","(23.8021441,90.3589601)","(23.8017154,90.3583084)","(23.8014311,90.3577971)","(23.8009495,90.357075)","(23.8006754,90.3566462)","(23.800214,90.3559342)","(23.799914,90.3555059)","(23.7995303,90.35484)","(23.7992737,90.3544338)","(23.7990169,90.3540286)","(23.7982719,90.3539519)","(23.7976706,90.3539462)","(23.7973404,90.3533206)","(23.7962074,90.3534043)","(23.7950709,90.3534892)","(23.7940059,90.3535911)","(23.7927969,90.3537025)","(23.7917167,90.3537679)","(23.7905262,90.353853)","(23.7893517,90.3539248)","(23.7881616,90.3539433)","(23.787051,90.3539749)","(23.7858809,90.3540298)","(23.7848306,90.3537706)","(23.7838713,90.3531696)","(23.7828781,90.3525578)","(23.7819908,90.3520807)","(23.7812682,90.3524867)","(23.7807123,90.353499)","(23.7802549,90.3543725)","(23.7796854,90.3555243)","(23.7791541,90.3568324)","(23.7789066,90.3585119)","(23.7785376,90.360115)","(23.777778,90.3615257)","(23.776938,90.3628635)","(23.7761069,90.3641037)","(23.775116,90.3654616)","(23.7741541,90.3665256)","(23.7729039,90.367457)","(23.771354,90.3680383)","(23.7699474,90.3685737)","(23.7686717,90.369079)","(23.7671273,90.3696705)","(23.7657432,90.3702273)","(23.7642913,90.3707992)","(23.7631293,90.3713298)","(23.7618621,90.3720514)","(23.7604578,90.3728846)","(23.7591099,90.3736883)","(23.7580333,90.3743938)","(23.7565418,90.3752261)","(23.7552056,90.3760217)","(23.7539862,90.3767417)","(23.7528017,90.3773744)","(23.7513405,90.3782242)","(23.7501863,90.3788964)","(23.7487592,90.3797473)","(23.747635,90.3803971)","(23.7463674,90.3811467)","(23.7450371,90.3819177)","(23.7435451,90.3823619)","(23.7423123,90.3826691)","(23.7408106,90.3830654)","(23.7393531,90.3833692)"}	f	0	abdulbari4	t	{"2024-03-04 00:34:43.67+06","2024-03-04 00:34:53.993+06","2024-03-04 00:35:04.719+06","2024-03-04 00:35:14.422+06","2024-03-04 00:35:24.641+06","2024-03-04 00:35:35.605+06","2024-03-04 00:35:45.592+06","2024-03-04 00:35:55.636+06","2024-03-04 00:36:05.675+06","2024-03-04 00:36:16.067+06"}
2421	2024-02-12 03:15:39.396938+06	5	afternoon	{"(36,\\"2024-02-12 03:16:05.105+06\\")","(37,\\"2024-02-12 03:19:00.758+06\\")","(38,\\"2024-02-12 03:20:56.766+06\\")","(39,\\"2024-02-12 03:22:19.866+06\\")","(40,\\"2024-02-12 03:23:32.83+06\\")",NULL}	from_buet	Ba-36-1921	t	ibrahim	\N	2024-02-12 03:24:48.731027+06	(23.7661817,90.3648933)	(23.7395582,90.3754016)	{"(23.7659622,90.3649718)","(23.7651634,90.3652736)","(23.7647095,90.3654216)","(23.7640315,90.3646333)","(23.7637991,90.3637885)","(23.7634575,90.3625919)","(23.7630971,90.3613989)","(23.7627795,90.3602297)","(23.7624104,90.359002)","(23.7615336,90.3588876)","(23.760428,90.3588847)","(23.7594333,90.3591194)","(23.7585554,90.3595922)","(23.7577281,90.3602782)","(23.7571314,90.3609583)","(23.754835,90.3642133)","(23.7543099,90.36487)","(23.7537867,90.3654761)","(23.7532401,90.36611)","(23.7527096,90.3667402)","(23.7521117,90.3673654)","(23.751416,90.3678828)","(23.7507733,90.3683257)","(23.7500552,90.3688201)","(23.7494098,90.3692685)","(23.7487186,90.3697499)","(23.7480381,90.3702121)","(23.7473629,90.370667)","(23.7464785,90.3712682)","(23.7451457,90.3721663)","(23.7444343,90.3726109)","(23.7437162,90.3731001)","(23.7430249,90.373575)","(23.742358,90.3739822)","(23.7417007,90.3743097)","(23.7408979,90.3747307)","(23.7401879,90.3750838)","(23.7394517,90.3754567)","(23.7387913,90.3758074)","(23.7382869,90.3762099)","(23.7385795,90.3757737)","(23.7391127,90.3755065)","(23.7395863,90.3752642)"}	f	0	mahabhu	t	\N
1953	2024-02-16 00:16:19.714502+06	3	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-24-8518	t	sohel55	nazmul	2024-02-16 00:16:31.696708+06	(23.7653679,90.3651872)	(23.7653656,90.3651881)	{"(23.765365,90.3651887)"}	f	0	alamgir	t	\N
2038	2024-02-16 00:38:15.638913+06	1	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-93-6087	t	sohel55	\N	2024-02-16 00:49:56.795421+06	(23.7625975,90.3702133)	(23.7573236,90.3606954)	{"(23.766005,90.3649567)","(23.7655532,90.3651249)","(23.7647081,90.3654216)","(23.7641903,90.3652492)","(23.7640398,90.3646632)","(23.7638733,90.36406)","(23.7637085,90.3634662)","(23.7635301,90.3628612)","(23.7633585,90.3622664)","(23.763173,90.3616603)","(23.7629933,90.3610452)","(23.7628267,90.3604167)","(23.7626549,90.3598217)","(23.7624735,90.359203)","(23.7619189,90.3588915)","(23.7614065,90.3589234)","(23.7609,90.35893)","(23.7603947,90.3588877)","(23.7599001,90.3589495)","(23.7594148,90.3591332)","(23.758946,90.359368)","(23.7585274,90.3596138)","(23.7580886,90.3599568)","(23.7576788,90.3603374)","(23.7573236,90.3606954)"}	f	0	alamgir	t	\N
2133	2024-02-06 19:54:49.635004+06	7	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	BA-01-2345	t	altaf	nazmul	2024-02-07 14:48:30.442322+06	(23.7626608,90.3702206)	(23.7626755,90.3702402)	{"(23.740763333333334,90.38307833333333)","(23.740763333333334,90.38307833333333)","(23.740763333333334,90.38307833333333)","(23.7626687,90.3702073)"}	f	0	jamal7898	t	\N
1935	2024-02-09 10:55:39.816801+06	5	evening	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:55:44.007+06\\")"}	from_buet	Ba-77-7044	t	rashed3	\N	2024-02-09 11:00:45.08317+06	(23.7275686,90.3917009)	(23.7275674,90.3917006)	{"(23.7275677,90.3917004)"}	f	0	reyazul	t	\N
2358	2024-02-12 12:57:00.241669+06	8	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-48-5757	t	ibrahim	\N	2024-02-12 14:28:42.208148+06	(23.7266942,90.3880456)	(23.740763333333334,90.38307833333333)	{"(23.72677915,90.38806052)","(23.740763333333334,90.38307833333333)"}	f	6	alamgir	t	\N
2331	2024-02-21 17:15:52.181503+06	8	evening	{"(64,\\"2024-02-21 17:18:34.556+06\\")","(65,\\"2024-02-21 17:17:53.218+06\\")","(66,\\"2024-02-21 17:22:03.292+06\\")","(67,\\"2024-02-21 17:22:24.974+06\\")","(68,\\"2024-02-21 17:23:27.528+06\\")","(69,\\"2024-02-21 17:22:56.145+06\\")",NULL}	from_buet	Ba-77-7044	t	ibrahim	nazmul	2024-02-21 17:25:33.144485+06	(23.8284333,90.3639183)	(23.7619373,90.3892609)	{"(23.8284539,90.3639148)","(23.8289354,90.3638419)","(23.8290012,90.3641058)","(23.8277019,90.3641885)","(23.8254727,90.3642437)","(23.8247732,90.3643063)","(23.8239554,90.3643687)","(23.8230997,90.364421)","(23.8222293,90.3645114)","(23.8214057,90.3647321)","(23.8206154,90.3649846)","(23.819797,90.3652)","(23.8189699,90.36536)","(23.8181725,90.365575)","(23.8174353,90.3657703)","(23.8165656,90.3660143)","(23.8157378,90.3662314)","(23.8148897,90.3664645)","(23.814078,90.3667498)","(23.8133478,90.3669478)","(23.8124705,90.3671754)","(23.8116493,90.367403)","(23.8108558,90.3675967)","(23.8099636,90.3678072)","(23.8090853,90.3680591)","(23.8082721,90.3683025)","(23.8075313,90.3685293)","(23.8065353,90.3687545)","(23.8055012,90.3692787)","(23.8042728,90.3698285)","(23.8031718,90.3703984)","(23.8020149,90.3708423)","(23.8008115,90.3713724)","(23.7991222,90.372049)","(23.7963483,90.3732533)","(23.7934217,90.374485)","(23.7913439,90.3753898)","(23.7886267,90.3765933)","(23.78637,90.377585)","(23.7841417,90.3784883)","(23.78174,90.37927)","(23.7794629,90.3798526)","(23.7772522,90.3805463)","(23.77467,90.38135)","(23.7725832,90.3819667)","(23.76993,90.38267)","(23.7675816,90.3830219)","(23.7653367,90.3835499)","(23.7648844,90.385988)","(23.764611,90.3875535)","(23.764497,90.3885752)","(23.7632132,90.3891503)","(23.7621425,90.3892582)"}	f	0	siddiq2	t	\N
2460	2024-02-21 17:27:23.602897+06	2	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-46-1334	t	ibrahim	\N	2024-02-21 17:27:31.676189+06	(23.7620507,90.3892586)	(23.7617414,90.3892614)	{"(23.7617414,90.3892614)"}	f	0	mahbub777	t	\N
2405	2024-02-21 22:39:35.037609+06	1	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-22-4326	t	altaf	\N	2024-02-21 22:39:53.084644+06	(23.8318635,90.3531771)	(23.8318635,90.3531757)	{"(23.831865,90.3531737)"}	f	0	sharif86r	t	\N
2406	2024-02-21 23:12:31.809782+06	1	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-22-4326	t	altaf	\N	2024-02-21 23:14:16.861847+06	(23.8318609,90.3531685)	(23.8318613,90.3531723)	{"(23.8318632,90.3531804)","(23.831864,90.3531779)"}	f	0	sharif86r	t	\N
3111	2024-04-22 09:06:55.615603+06	5	afternoon	{"(70,\\"2024-03-04 09:06:57.005+06\\")","(40,\\"2024-03-04 09:18:01.651+06\\")","(39,\\"2024-03-04 09:20:51.157+06\\")","(38,\\"2024-03-04 09:23:42.701+06\\")","(37,\\"2024-03-04 09:27:16.161+06\\")","(36,\\"2024-03-04 09:35:07.632+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	2024-04-22 23:46:17.283918+06	(23.7268517,90.3917017)	(37.4219983,-122.084)	{"(23.7268517,90.3917017)","(23.7268476,90.3917015)","(23.726321,90.3917681)","(23.7258706,90.3918399)","(23.7260569,90.3913737)","(23.726331,90.3909291)","(23.7266297,90.3904924)","(23.7269589,90.3900458)","(23.7272675,90.3896295)","(23.7278697,90.3890803)","(23.7282796,90.38877)","(23.7286846,90.3883736)","(23.7290435,90.3880545)","(23.7294606,90.3877187)","(23.7298723,90.3874703)","(23.7303606,90.3872581)","(23.7308144,90.3871)","(23.7313341,90.3869831)","(23.7319069,90.3868996)","(23.7324315,90.3869385)","(23.7324702,90.3864308)","(23.7323768,90.3857072)","(23.7323534,90.3850171)","(23.7330681,90.3847801)","(23.7338049,90.384565)","(23.7345088,90.384411)","(23.7350174,90.3842927)","(23.7355618,90.384135)","(23.736038,90.3840098)","(23.7366513,90.3838606)","(23.7371179,90.38376)","(23.7377086,90.3836121)","(23.7381566,90.3835067)","(23.7388289,90.3833602)","(23.7394739,90.3831552)","(23.7393235,90.3823822)","(23.7391735,90.3816189)","(23.7390234,90.380842)","(23.7388634,90.3800352)","(23.7387519,90.3794446)","(23.7386274,90.3788534)","(23.7385603,90.3783068)","(23.7384703,90.3776219)","(23.7383685,90.3768191)","(23.73832,90.3760705)","(23.7389262,90.3756185)","(23.7393498,90.3753943)","(23.7401281,90.3749851)","(23.7405448,90.3747684)","(23.7410624,90.3745175)","(23.7417321,90.3741452)","(23.7421505,90.3739489)","(23.7426053,90.3737198)","(23.7429999,90.3734559)","(23.7436706,90.3729959)","(23.7440925,90.3727234)","(23.7447676,90.3722323)","(23.745491,90.3717606)","(23.7459104,90.3714859)","(23.7465714,90.3710336)","(23.7469895,90.3707621)","(23.7473953,90.3704919)","(23.7481113,90.3700036)","(23.7488398,90.3694901)","(23.7495675,90.369002)","(23.750288,90.36851)","(23.7507627,90.3682028)","(23.7513807,90.3677664)","(23.7518521,90.3674409)","(23.752466,90.3668963)","(23.7527785,90.3665318)","(23.7531156,90.3661407)","(23.753654,90.3655161)","(23.7539624,90.3651577)","(23.7542777,90.3647757)","(23.7545896,90.3644071)","(23.7549101,90.3640153)","(23.7554498,90.3633802)","(23.7557613,90.3630104)","(23.7563598,90.3622969)","(23.7569516,90.3615834)","(23.7570456,90.3609426)","(23.7569085,90.3603264)","(23.7567766,90.3598264)","(23.7565525,90.3591808)","(23.7568914,90.3598161)","(23.7570482,90.3605029)","(23.7571201,90.3610604)","(23.7571296,90.3616597)","(23.7575616,90.3622415)","(23.7579883,90.3629031)","(23.7583675,90.3635726)","(23.758596,90.3640359)","(23.7588997,90.3646329)","(23.7591036,90.3650823)","(23.7593896,90.3656782)","(23.759891,90.3655335)","(23.7603997,90.3653701)","(23.7608714,90.3651634)","(23.7613798,90.3649967)","(23.7618498,90.364835)","(23.7623532,90.3646584)","(23.7628613,90.3644813)","(23.763347,90.3643174)","(23.7638326,90.3641398)","(23.7640559,90.3647192)","(23.7642445,90.3653868)","(23.7649025,90.3652887)","(23.7653428,90.3651291)","(23.7659828,90.3648869)","(23.7667046,90.3646668)","(23.7671709,90.3644997)","(37.4220936,-122.083922)"}	f	32	mahbub777	t	{"2024-03-04 09:35:28.14+06","2024-03-04 09:35:48.621+06","2024-03-04 09:36:09.63+06","2024-03-04 09:36:30.62+06","2024-03-04 09:36:51.65+06","2024-03-04 09:37:07.257+06","2024-03-04 09:37:22.615+06","2024-03-04 09:37:43.253+06","2024-03-04 09:38:04.392+06","2024-04-22 23:45:38.467+06"}
2870	2024-04-20 00:40:48.417044+06	4	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-03-04 00:40:55.555+06\\")"}	from_buet	Ba-98-5568	t	sohel55	nazmul	2024-03-04 08:00:40.224877+06	(23.7275967,90.3917001)	(23.7562849,90.3753603)	{"(23.7275971,90.3917001)","(37.4220936,-122.083922)","(23.7562849,90.3753603)"}	f	29	zahir53	t	{"2024-03-04 00:40:55.555+06","2024-03-04 08:00:30.222+06","2024-03-04 08:00:40.204+06"}
2831	2024-04-19 00:38:58.239619+06	7	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-03-04 00:39:04.007+06\\")"}	to_buet	Ba-46-1334	t	shahid88	mashroor	2024-03-04 00:39:14.217699+06	(23.7275925,90.3917002)	(23.727435,90.3917026)	{"(23.7274107,90.3917045)"}	f	0	shamsul54	t	{"2024-03-04 00:39:04.007+06"}
2843	2024-04-20 00:39:50.203272+06	4	afternoon	{"(27,\\"1970-01-01 06:00:00+06\\")","(28,\\"1970-01-01 06:00:00+06\\")","(29,\\"1970-01-01 06:00:00+06\\")","(30,\\"1970-01-01 06:00:00+06\\")","(31,\\"1970-01-01 06:00:00+06\\")","(32,\\"1970-01-01 06:00:00+06\\")","(33,\\"1970-01-01 06:00:00+06\\")","(34,\\"1970-01-01 06:00:00+06\\")","(35,\\"1970-01-01 06:00:00+06\\")","(70,\\"1970-01-01 06:00:00+06\\")"}	from_buet	BA-01-2345	t	ibrahim	mashroor	\N	(23.7274369,90.3917026)	\N	{}	f	65	siddiq2	t	{}
2161	2024-02-07 14:59:32.16427+06	8	morning	{"(64,\\"2024-02-07 12:10:00+06\\")","(65,\\"2024-02-07 12:13:00+06\\")","(66,\\"2024-02-07 12:18:00+06\\")","(67,\\"2024-02-07 12:20:00+06\\")","(68,\\"2024-02-07 12:22:00+06\\")","(69,\\"2024-02-07 12:25:00+06\\")","(70,\\"2024-02-07 12:40:00+06\\")"}	to_buet	Ba-12-8888	t	altaf	nazmul	\N	(23.7626675,90.3702308)	\N	{"(23.7626823,90.3702164)"}	f	0	sharif86r	t	\N
2164	2024-02-07 15:35:45.935618+06	2	morning	{"(12,\\"1970-01-01 06:00:00+06\\")","(13,\\"1970-01-01 06:00:00+06\\")","(14,\\"1970-01-01 06:00:00+06\\")","(15,\\"1970-01-01 06:00:00+06\\")","(16,\\"1970-01-01 06:00:00+06\\")","(70,\\"1970-01-01 06:00:00+06\\")"}	to_buet	Ba-17-3886	t	altaf	nazmul	\N	(23.7626796,90.3702159)	\N	{"(23.7626839,90.3702222)"}	f	0	siddiq2	t	\N
2053	2024-02-09 11:01:01.058033+06	5	morning	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 11:01:05.985+06\\")"}	to_buet	Ba-22-4326	t	rashed3	nazmul	2024-02-09 11:02:51.355694+06	(23.7276,90.3917)	(23.7275685,90.3917004)	{"(23.7275743,90.3917007)"}	f	0	ASADUZZAMAN	t	\N
2503	2024-02-12 14:31:06.983535+06	7	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-97-6734	t	ibrahim	\N	2024-02-12 14:31:13.713686+06	(23.740763333333334,90.38307833333333)	(23.740763333333334,90.38307833333333)	{"(23.740763333333334,90.38307833333333)"}	f	0	khairul	t	\N
2459	2024-02-12 14:31:16.892462+06	2	morning	{NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-46-1334	t	ibrahim	\N	2024-02-12 14:31:19.634503+06	(23.740763333333334,90.38307833333333)	(23.740763333333334,90.38307833333333)	{}	f	0	mahbub777	t	\N
2505	2024-02-12 14:46:33.32274+06	7	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-97-6734	t	ibrahim	\N	2024-02-12 14:47:55.585077+06	(23.76381,90.3638183)	(23.7638074,90.3638071)	{"(23.76381,90.36381833333333)"}	f	0	khairul	t	\N
2360	2024-02-17 14:59:26.404466+06	8	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-48-5757	t	ibrahim	\N	2024-02-12 15:31:15.114057+06	(23.76381,90.3638183)	(23.7638074,90.3638071)	{"(23.76381,90.36381833333333)","(23.7267146,90.3881745)"}	f	4	alamgir	t	\N
2372	2024-02-13 14:32:35.949487+06	5	afternoon	{"(36,\\"2024-02-12 14:32:51.365+06\\")",NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-83-8014	t	ibrahim	\N	2024-02-12 14:45:41.563931+06	(23.740763333333334,90.38307833333333)	(23.7638074,90.3638072)	{"(23.765681666666666,90.36507666666667)","(23.76481666666667,90.36538666666667)","(23.764236666666665,90.36535833333333)","(23.764071666666666,90.36477833333333)","(23.763905,90.36417833333333)","(23.76381,90.36381833333333)","(23.76381,90.36381833333333)"}	f	0	alamgir	t	\N
2670	2024-03-03 01:25:25.064138+06	6	afternoon	{"(41,\\"2024-03-03 01:25:26.574+06\\")","(42,\\"2024-03-03 01:27:46.525+06\\")","(43,\\"2024-03-03 01:37:06.577+06\\")","(44,\\"2024-03-03 01:39:22.051+06\\")","(45,\\"2024-03-03 01:40:16.583+06\\")","(46,\\"2024-03-03 01:42:16.625+06\\")","(47,\\"2024-03-03 01:46:25.495+06\\")","(48,\\"2024-03-03 01:48:10.497+06\\")","(49,\\"2024-03-03 01:49:15.647+06\\")","(70,\\"2024-03-03 02:08:31.078+06\\")"}	from_buet	Ba-71-7930	t	rahmatullah	nazmul	2024-03-03 02:18:38.38825+06	(23.80698,90.36877)	(23.8028549,90.3601058)	{"(23.8069702,90.3687603)","(23.8069309,90.3681744)","(23.8068203,90.3676137)","(23.8066917,90.3669784)","(23.8064857,90.3662446)","(23.8061774,90.3655231)","(23.8058037,90.3648462)","(23.8054343,90.3642178)","(23.8050768,90.363603)","(23.8047513,90.3629419)","(23.8044801,90.3625286)","(23.804142,90.3620247)","(23.8038283,90.3615735)","(23.8035228,90.3611404)","(23.8031879,90.3606103)","(23.8036701,90.3610709)","(23.80412,90.3617984)","(23.8045841,90.3625013)","(23.8050573,90.3632233)","(23.8054124,90.3639524)","(23.8056819,90.3644071)","(23.8060529,90.3650327)","(23.8056249,90.3645607)","(23.8052967,90.3639803)","(23.804966,90.3633981)","(23.8046406,90.3627893)","(23.8043067,90.3622639)","(23.8038983,90.3616732)","(23.8035884,90.3612355)","(23.8031564,90.3605589)","(23.8028455,90.3601027)","(23.8024117,90.3594018)","(23.8021534,90.3589935)","(23.8016677,90.3582217)","(23.8012139,90.3574834)","(23.8009001,90.3570005)","(23.8004956,90.3563772)","(23.8001687,90.3558583)","(23.7996712,90.3553905)","(23.7995072,90.3547956)","(23.7991365,90.354221)","(23.79877,90.3536401)","(23.7982713,90.3539468)","(23.7977972,90.3539508)","(23.7975187,90.3535487)","(23.7968662,90.3533596)","(23.7963001,90.3534017)","(23.7956986,90.3534334)","(23.7951628,90.3534796)","(23.7946209,90.3535278)","(23.7941483,90.3535683)","(23.7935545,90.3536429)","(23.7930066,90.353694)","(23.7924493,90.3537345)","(23.7919563,90.3537598)","(23.7913715,90.3537872)","(23.7908321,90.3538377)","(23.7902884,90.3538695)","(23.7897408,90.3539044)","(23.7892483,90.3539336)","(23.7886419,90.3539474)","(23.7880903,90.3539421)","(23.787538,90.3539499)","(23.7869827,90.3539772)","(23.7864864,90.3540092)","(23.7858853,90.3540351)","(23.7853512,90.3540104)","(23.7848503,90.3537919)","(23.7843712,90.3534926)","(23.7839166,90.3531986)","(23.7833983,90.3528733)","(23.7829246,90.3525866)","(23.7824856,90.3523322)","(23.7820385,90.3521018)","(23.7814709,90.3518189)","(23.7812625,90.3523678)","(23.7810222,90.352929)","(23.7807787,90.3533727)","(23.7805399,90.3538298)","(23.780297,90.3542866)","(23.7800861,90.354737)","(23.7797066,90.3554915)","(23.7794453,90.3559621)","(23.7791952,90.3565066)","(23.7791016,90.3570762)","(23.7790391,90.3575835)","(23.7789639,90.3581049)","(23.778895,90.3586195)","(23.7788157,90.359141)","(23.7787152,90.3596287)","(23.7785312,90.3601503)","(23.7783465,90.3606247)","(23.778084,90.3610431)","(23.7778115,90.3614831)","(23.777552,90.3619022)","(23.7772035,90.3624597)","(23.7769,90.3629224)","(23.7766283,90.3633385)","(23.7763321,90.3637751)","(23.776042,90.3641947)","(23.7757201,90.364645)","(23.7754275,90.3650497)","(23.775078,90.365505)","(23.7747399,90.3658722)","(23.7743904,90.3662799)","(23.7739828,90.3666909)","(23.7735655,90.3670323)","(23.7731835,90.3673366)","(23.7726776,90.3675458)","(23.7722081,90.3677191)","(23.7717554,90.3678817)","(23.7713032,90.3680547)","(23.7705705,90.3683189)","(23.770133,90.3684931)","(23.7696381,90.3687053)","(23.7691903,90.3688775)","(23.7687405,90.3690424)","(23.7682962,90.3692307)","(23.7678423,90.3694104)","(23.7673879,90.369574)","(23.7669304,90.369747)","(23.7664877,90.369922)","(23.7660373,90.3701042)","(23.7656052,90.3702832)","(23.7651537,90.3704666)","(23.7647074,90.3706356)","(23.7642214,90.3708297)","(23.7637806,90.371018)","(23.7633523,90.3711852)","(23.7629338,90.3714242)","(23.7625278,90.3716713)","(23.7621033,90.3719211)","(23.761667,90.3721586)","(23.7612577,90.3723924)","(23.760831,90.3726601)","(23.7602208,90.3730243)","(23.7597901,90.3732707)","(23.759222,90.3736076)","(23.7587622,90.3739141)","(23.7580732,90.3743787)","(23.7575968,90.3746076)","(23.7571701,90.3748481)","(23.7567592,90.3751008)","(23.7563169,90.3753534)","(23.755859,90.3756274)","(23.7554288,90.3758801)","(23.7550193,90.3761398)","(23.7545559,90.3764266)","(23.7541449,90.3766837)","(23.7536453,90.3769268)","(23.7531787,90.3771881)","(23.7527039,90.3774257)","(23.7522431,90.3776913)","(23.7518005,90.3779549)","(23.7513665,90.3782084)","(23.750839,90.3785043)","(23.7503818,90.3787787)","(23.7496585,90.3792108)","(23.7492321,90.3794683)","(23.7488351,90.379704)","(23.7483392,90.3799794)","(23.7478705,90.3802567)","(23.7474629,90.3805058)","(23.74701,90.3807815)","(23.7465877,90.3810205)","(23.7461272,90.3812851)","(23.74569,90.38154)","(23.745287,90.3817806)","(23.7448281,90.382029)","(23.7443597,90.3821754)","(23.743847,90.3822919)","(23.7433538,90.3824082)","(23.7428652,90.3825348)","(23.74238,90.3826534)","(23.7419001,90.3827699)","(23.7414083,90.3829016)","(23.7409453,90.3830284)","(23.7404618,90.3831502)","(23.7399559,90.3832453)","(23.739448,90.3833482)","(23.7389776,90.38345)","(23.7384995,90.3835502)","(23.7380004,90.3837078)","(23.737543,90.3838502)","(23.7370946,90.3839214)","(23.736625,90.3840138)","(23.7361631,90.3841028)","(23.7357022,90.3842178)","(23.7352344,90.384356)","(23.7345991,90.3845244)","(23.7340977,90.3846325)","(23.7335853,90.384768)","(23.7329606,90.3849363)","(23.7324805,90.3853001)","(23.7325017,90.3860251)","(23.7325984,90.3867299)","(23.7322518,90.387083)","(23.7317091,90.3869827)","(23.7311969,90.3869244)","(23.7307631,90.3870614)","(23.7302232,90.3872918)","(23.7297396,90.387517)","(23.729201,90.387921)","(23.7288175,90.3882515)","(23.7283893,90.3886593)","(23.7279959,90.389062)","(23.7276236,90.3894404)","(23.7271088,90.3899586)","(23.7276017,90.3903259)","(23.7277652,90.3908487)","(23.727963,90.3914012)","(23.7275316,90.3917057)","(23.807131,90.3688198)","(23.8069013,90.3680261)","(23.8067433,90.3672336)","(23.8065705,90.3664886)","(23.8063452,90.3658226)","(23.8059843,90.3651726)","(23.8056302,90.3645449)","(23.8053751,90.3641139)","(23.8050751,90.36359)","(23.8048343,90.3631173)","(23.8045418,90.3626243)","(23.8042269,90.36215)","(23.8039326,90.3617231)","(23.803578,90.3612177)","(23.8031879,90.3606103)","(23.8036484,90.3610357)","(23.8039125,90.3614631)","(23.8043325,90.3621248)","(23.8048105,90.3628483)","(23.8052016,90.3635836)","(23.8056199,90.3643041)","(23.805868,90.3647195)","(23.80624,90.3654067)","(23.8056199,90.3645869)","(23.8053416,90.3640568)","(23.8049706,90.3634069)","(23.8046722,90.3628429)","(23.8044185,90.3624366)","(23.8040959,90.3619545)","(23.8036593,90.3613386)","(23.8033924,90.36094)","(23.803133,90.3605206)","(23.8028549,90.3601058)"}	f	0	mahabhu	t	\N
2656	2024-03-03 01:26:21.278331+06	5	evening	{NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-03-03 01:43:33.936+06\\")"}	from_buet	Ba-20-3066	t	shahid88	nazmul	2024-03-03 02:18:41.061591+06	(37.4219983,-122.084)	(23.7357584,90.3842099)	{"(37.4219983,-122.084)","(23.7648551,90.3630366)","(23.7645227,90.3634293)","(23.7640135,90.3636165)","(23.76391,90.3642045)","(23.7634177,90.3642912)","(23.7629087,90.3644668)","(23.7623777,90.3646483)","(23.7618702,90.3648284)","(23.7613331,90.365011)","(23.7608182,90.3651806)","(23.7604001,90.3653691)","(23.7598669,90.3655405)","(23.7593135,90.3657002)","(23.7590618,90.3651212)","(23.758825,90.3646017)","(23.7585454,90.364051)","(23.7582633,90.3635319)","(23.7577254,90.3636221)","(23.7571969,90.3638156)","(23.7565943,90.3639711)","(23.7560714,90.3641803)","(23.7555087,90.364376)","(23.7550634,90.3641302)","(23.7545392,90.3643656)","(23.7540208,90.3652269)","(23.7533943,90.3659334)","(23.7528883,90.366526)","(23.7522799,90.3672454)","(23.7516974,90.3677167)","(23.7509056,90.3682589)","(23.7502563,90.3686778)","(23.7495484,90.3691726)","(23.7489177,90.3696159)","(23.7481838,90.3701191)","(23.7474933,90.3705786)","(23.7468181,90.3710316)","(23.7461447,90.3714944)","(23.74541,90.3719876)","(23.7446606,90.3724954)","(23.7439927,90.3728973)","(23.7433083,90.3733749)","(23.7426311,90.3738432)","(23.7418676,90.3742435)","(23.7411445,90.3746108)","(23.7403443,90.3750133)","(23.7396256,90.3753526)","(23.7388754,90.3757664)","(23.738166,90.3762164)","(23.7384418,90.3773216)","(23.7386309,90.3782318)","(23.7387521,90.3791102)","(23.7389494,90.3800479)","(23.7391228,90.380961)","(23.7397878,90.3808425)","(23.7403435,90.3809364)","(23.7403441,90.3817352)","(23.7404769,90.3824403)","(23.7406201,90.3831963)","(23.7399723,90.3832969)","(23.7393484,90.3833653)","(23.7387627,90.3834888)","(23.7381703,90.383649)","(23.7375314,90.383826)","(23.7369668,90.3839413)","(23.736315,90.384073)","(23.7356999,90.3842219)","(23.7351395,90.3843777)","(23.7345264,90.3845424)","(23.7338826,90.3846882)","(23.7332999,90.3848459)","(23.7326922,90.3850122)","(23.7324085,90.3855764)","(23.7325128,90.3862133)","(23.7326183,90.3868742)","(23.7321784,90.3871312)","(23.7311679,90.3869693)","(23.730212,90.3872876)","(23.7293951,90.3877286)","(23.7286373,90.3883972)","(23.7279013,90.3891535)","(23.7272213,90.3898577)","(23.7275628,90.3902634)","(23.727912,90.3912697)","(23.727697,90.3917465)","(23.76473,90.36242)","(23.7648344,90.36297)","(23.7644168,90.3634667)","(23.7638986,90.3636601)","(23.763656,90.3642038)","(23.7630384,90.3644251)","(23.7624117,90.3646367)","(23.7617807,90.3648599)","(23.7611533,90.3650665)","(23.7605268,90.3653081)","(23.7601001,90.365469)","(23.7594732,90.3656551)","(23.7590876,90.3651813)","(23.75875,90.3644572)","(23.7583784,90.3637468)","(23.7578871,90.3635553)","(23.75736,90.3637603)","(23.7568073,90.3639402)","(23.7562651,90.3641184)","(23.7557316,90.3642967)","(23.7552043,90.3641425)","(23.7547391,90.3643285)","(23.7541949,90.3650022)","(23.7536301,90.3656568)","(23.7530451,90.3663446)","(23.7524927,90.3669973)","(23.751874,90.3675675)","(23.751188,90.3680528)","(23.7504946,90.3685191)","(23.7498267,90.3689781)","(23.7494404,90.3692482)","(23.7490318,90.3695342)","(23.748437,90.3699409)","(23.7480521,90.3702076)","(23.7476546,90.3704694)","(23.7470233,90.3708968)","(23.7465891,90.3711913)","(23.745981,90.3715952)","(23.7455519,90.37189)","(23.7449225,90.3723162)","(23.7445082,90.3725611)","(23.7438644,90.3730053)","(23.7434543,90.373282)","(23.7428362,90.3737031)","(23.7423921,90.3739668)","(23.7417091,90.3742814)","(23.7412729,90.374543)","(23.740599,90.3748803)","(23.7401462,90.375103)","(23.7394693,90.3754445)","(23.7390495,90.3756682)","(23.7383744,90.3760415)","(23.7382626,90.3765382)","(23.7384737,90.3770053)","(23.7385435,90.3775753)","(23.7386701,90.3783868)","(23.7387402,90.3789502)","(23.7388884,90.3797268)","(23.7389935,90.3802752)","(23.7391554,90.3810926)","(23.7395539,90.3808099)","(23.7402187,90.3806178)","(23.7402474,90.3812526)","(23.7403692,90.3818663)","(23.7404637,90.3823708)","(23.7405769,90.3829678)","(23.7400523,90.3832303)","(23.7395549,90.3833143)","(23.738934,90.3834504)","(23.7383239,90.3836015)","(23.7377184,90.3837818)","(23.7371252,90.3839091)","(23.7365033,90.3840374)","(23.735888,90.384175)"}	f	0	nasir81	t	\N
2673	2024-03-03 01:25:28.557447+06	7	afternoon	{"(50,\\"2024-03-03 01:36:14.505+06\\")","(51,\\"2024-03-03 01:39:40.041+06\\")","(52,\\"2024-03-03 01:41:19+06\\")","(53,\\"2024-03-03 01:43:40.065+06\\")",NULL,"(55,\\"2024-03-03 01:45:20.09+06\\")",NULL,"(57,\\"2024-03-03 01:47:30.081+06\\")","(58,\\"2024-03-03 01:48:20.088+06\\")","(59,\\"2024-03-03 01:48:50.09+06\\")","(60,\\"2024-03-03 01:50:00.094+06\\")",NULL,NULL,NULL,"(70,\\"2024-03-03 02:11:10.244+06\\")"}	from_buet	Ba-35-1461	t	rashed3	nazmul	2024-03-03 02:18:41.66078+06	(23.8742633,90.3855)	(23.8746199,90.3992126)	{"(23.8742639,90.3855205)","(23.8742735,90.3860828)","(23.8742808,90.3866119)","(23.8742883,90.3872382)","(23.8743098,90.3879572)","(23.8743198,90.3887084)","(23.8743435,90.3894648)","(23.8743535,90.3902147)","(23.8743621,90.3909404)","(23.8743836,90.3916508)","(23.8743919,90.3923682)","(23.87439,90.3928951)","(23.87439,90.3934217)","(23.8744081,90.3940019)","(23.8744239,90.3945214)","(23.8744584,90.3951482)","(23.8744933,90.395931)","(23.8745268,90.3966737)","(23.8745627,90.3973907)","(23.8746087,90.3981085)","(23.8746155,90.3988223)","(23.87462,90.3993463)","(23.87462,90.399916)","(23.8746403,90.4004872)","(23.873962,90.4006629)","(23.8733987,90.4007204)","(23.8726764,90.4007136)","(23.8721873,90.4006894)","(23.8714196,90.4006401)","(23.8709639,90.4006146)","(23.8701255,90.4005353)","(23.869673,90.4004915)","(23.8689239,90.4004325)","(23.86842,90.4003703)","(23.8679664,90.400374)","(23.8672929,90.4003515)","(23.8666918,90.40032)","(23.8660772,90.4002951)","(23.8654684,90.4002539)","(23.8648758,90.4001735)","(23.8641663,90.4001498)","(23.8636741,90.4001338)","(23.8627812,90.4000416)","(23.8617705,90.4000559)","(23.8608098,90.4003077)","(23.8599407,90.4007941)","(23.8591796,90.401286)","(23.8585439,90.4018911)","(23.8580152,90.4023885)","(23.8573073,90.4029596)","(23.8566957,90.4034848)","(23.8561805,90.403965)","(23.8554359,90.4045626)","(23.854801,90.4050565)","(23.854185,90.4056027)","(23.8535253,90.406071)","(23.8529452,90.406622)","(23.8523981,90.4070811)","(23.8517964,90.4075899)","(23.8511119,90.4081711)","(23.8504714,90.4086414)","(23.8498536,90.4090903)","(23.84933,90.4096195)","(23.8487168,90.410119)","(23.8481005,90.4106118)","(23.8474603,90.4111298)","(23.8468483,90.4116316)","(23.8462202,90.4121498)","(23.8456961,90.4126018)","(23.8450277,90.4131468)","(23.8444155,90.4136498)","(23.8437499,90.4149296)","(23.8426387,90.416269)","(23.8408127,90.4174292)","(23.8396779,90.4184344)","(23.8383135,90.4192685)","(23.8365865,90.4195182)","(23.8352297,90.4196147)","(23.8334453,90.4198822)","(23.8318225,90.4201224)","(23.8302254,90.4203754)","(23.8286225,90.4206371)","(23.8270393,90.4212129)","(23.8255965,90.4220049)","(23.8240519,90.4225463)","(23.822628,90.4223827)","(23.8209685,90.4215101)","(23.8198622,90.4201791)","(23.8193414,90.4187791)","(23.8190801,90.4168328)","(23.8185299,90.415251)","(23.8174867,90.4138768)","(23.8164119,90.4124845)","(23.8155175,90.4110902)","(23.8146152,90.4094558)","(23.8138204,90.4078478)","(23.8130858,90.4064014)","(23.8121797,90.4051162)","(23.8112055,90.404093)","(23.8094358,90.4029582)","(23.8080475,90.4027654)","(23.8062128,90.4026729)","(23.8048461,90.4024339)","(23.8030653,90.4021433)","(23.801449,90.4018788)","(23.8000067,90.4016984)","(23.7982703,90.4013657)","(23.7968907,90.4010832)","(23.7951236,90.4006177)","(23.7935594,90.4003226)","(23.7921607,90.4000994)","(23.7904029,90.3998139)","(23.7888197,90.399544)","(23.7871877,90.3992811)","(23.7855887,90.3990361)","(23.7841648,90.3988154)","(23.7824049,90.3985155)","(23.7808118,90.3982473)","(23.7791775,90.3980027)","(23.7775792,90.3977285)","(23.7760703,90.3974818)","(23.7743486,90.3971967)","(23.7726213,90.3969167)","(23.771032,90.3966702)","(23.7697567,90.3964754)","(23.7679722,90.3961095)","(23.7664533,90.3957878)","(23.7648411,90.3953647)","(23.7636899,90.3950498)","(23.7623323,90.3949163)","(23.7610938,90.394836)","(23.7598523,90.394666)","(23.7585703,90.3944377)","(23.7572795,90.3942196)","(23.7571295,90.3928823)","(23.7578859,90.3914111)","(23.7584743,90.3901713)","(23.75858,90.3888505)","(23.7584345,90.3874482)","(23.7582833,90.386737)","(23.7582438,90.3861423)","(23.75819,90.3854856)","(23.7581346,90.3848753)","(23.7580819,90.3842676)","(23.758112,90.3836504)","(23.7584769,90.3832638)","(23.7585139,90.382594)","(23.7584699,90.3817763)","(23.7584511,90.3809747)","(23.7584152,90.3801286)","(23.75836,90.3793388)","(23.7583226,90.3784974)","(23.7582802,90.3777751)","(23.7582646,90.3769364)","(23.7582531,90.3761621)","(23.758235,90.3753997)","(23.7581614,90.3748277)","(23.7576473,90.3745768)","(23.7572179,90.3748127)","(23.7565028,90.3752477)","(23.7561014,90.3754835)","(23.7556968,90.3757239)","(23.7550185,90.3761188)","(23.7546047,90.376396)","(23.7539517,90.3768248)","(23.7534342,90.3770454)","(23.7528609,90.3773444)","(23.7524357,90.3775661)","(23.7518203,90.3779433)","(23.7513251,90.3782342)","(23.7506598,90.3786132)","(23.7499188,90.3790526)","(23.7495136,90.3792984)","(23.7491055,90.379545)","(23.7483456,90.3799743)","(23.7476373,90.3803948)","(23.7471801,90.3806898)","(23.7467692,90.3809158)","(23.746162,90.3812666)","(23.7456404,90.38157)","(23.745217,90.3818191)","(23.7446706,90.3821072)","(23.7439835,90.3822603)","(23.7434397,90.3823881)","(23.7426602,90.3825883)","(23.7422125,90.3826921)","(23.7413951,90.3829051)","(23.7409483,90.3830269)","(23.7401839,90.3832187)","(23.7396951,90.3832908)","(23.7390247,90.38344)","(23.7385766,90.3835266)","(23.73793,90.3837299)","(23.7374792,90.3838339)","(23.736922,90.3839518)","(23.7361599,90.3841101)","(23.7357105,90.3842215)","(23.734884,90.3844482)","(23.734047,90.3846449)","(23.7332652,90.3848555)","(23.7328166,90.3849774)","(23.7323537,90.3853538)","(23.7324938,90.3860237)","(23.7325701,90.3865165)","(23.7326426,90.3870442)","(23.7321493,90.3870175)","(23.7316131,90.3869585)","(23.7310531,90.3870339)","(23.7305356,90.3871924)","(23.7300945,90.387362)","(23.7296018,90.3876289)","(23.7291602,90.3879544)","(23.7287433,90.3883196)","(23.7283532,90.3886948)","(23.7279635,90.3890945)","(23.7276239,90.3894398)","(23.7275859,90.3902884)","(23.7277228,90.3907813)","(23.7279391,90.3913346)","(23.7274482,90.3917095)","(23.8742601,90.3851914)","(23.8742747,90.3859141)","(23.8742783,90.3864815)","(23.8742857,90.3870022)","(23.8742967,90.3876181)","(23.8743101,90.3883497)","(23.8743351,90.3891399)","(23.8743562,90.3898977)","(23.8743584,90.3905961)","(23.8743813,90.391318)","(23.8743867,90.3920367)","(23.8743901,90.3925891)","(23.87439,90.3931249)","(23.8744053,90.3937248)","(23.8744233,90.3944987)","(23.8744651,90.3952915)","(23.8744967,90.3960205)","(23.8745291,90.3967163)","(23.8745618,90.3974179)","(23.8745951,90.3979568)","(23.8746135,90.3984592)","(23.8746183,90.3991048)"}	f	0	rashid56	t	\N
2680	2024-03-03 01:25:50.564228+06	8	evening	{"(64,\\"2024-03-03 01:31:31.997+06\\")","(65,\\"2024-03-03 01:30:01.998+06\\")","(66,\\"2024-03-03 01:38:32.059+06\\")","(67,\\"2024-03-03 01:40:42.091+06\\")","(68,\\"2024-03-03 01:44:22.123+06\\")","(69,\\"2024-03-03 01:42:42.097+06\\")","(70,\\"2024-03-03 02:07:28.961+06\\")"}	from_buet	BA-01-2345	t	altaf	nazmul	2024-03-03 02:18:43.072386+06	(23.8292483,90.3638067)	(23.8104404,90.3677001)	{"(23.8292673,90.3638045)","(23.8288628,90.3641082)","(23.8283906,90.364165)","(23.8276229,90.3642161)","(23.8271198,90.3642503)","(23.8263641,90.36425)","(23.8258878,90.3642494)","(23.8251274,90.3642603)","(23.8243039,90.3643624)","(23.8234963,90.3644039)","(23.8229979,90.3644316)","(23.8222539,90.3645038)","(23.8217135,90.3646472)","(23.8210598,90.3648359)","(23.8204537,90.3650418)","(23.8199274,90.3651825)","(23.8192088,90.3653083)","(23.8186855,90.365435)","(23.8179752,90.3656282)","(23.8174854,90.3657579)","(23.816692,90.3659819)","(23.8158836,90.3661873)","(23.8151309,90.3664058)","(23.8146373,90.366553)","(23.8139954,90.3667784)","(23.8134124,90.3669306)","(23.8127793,90.367109)","(23.8122214,90.367245)","(23.8115971,90.3674201)","(23.8109526,90.3675749)","(23.8104044,90.3677042)","(23.8097128,90.3678783)","(23.8092254,90.3680145)","(23.8085109,90.3682336)","(23.8080666,90.3683642)","(23.807294,90.3685983)","(23.8062915,90.3688749)","(23.8057577,90.3691295)","(23.805327,90.3693607)","(23.8047179,90.3696545)","(23.8042186,90.3698544)","(23.8036257,90.3701378)","(23.8031053,90.3704382)","(23.802527,90.370613)","(23.801975,90.3708552)","(23.8014888,90.3710664)","(23.8009269,90.3713189)","(23.8003097,90.3715826)","(23.7997454,90.3717977)","(23.7991766,90.3720262)","(23.7986383,90.3722673)","(23.7980792,90.3725187)","(23.7975159,90.3727509)","(23.7970163,90.3729767)","(23.7963964,90.3732341)","(23.7958799,90.3734649)","(23.7953412,90.373704)","(23.794723,90.3739498)","(23.7941564,90.3741688)","(23.7936099,90.3744035)","(23.7930481,90.3746419)","(23.7924828,90.3749058)","(23.7919334,90.3751245)","(23.7913801,90.3753565)","(23.7908334,90.3756114)","(23.7902689,90.3758356)","(23.7897404,90.3761056)","(23.789183,90.3763411)","(23.7886337,90.3766095)","(23.7881161,90.3768052)","(23.7875125,90.377093)","(23.7869748,90.3773236)","(23.7864093,90.3775552)","(23.7858586,90.3778182)","(23.7853132,90.3780493)","(23.7847387,90.3782731)","(23.7842295,90.3784565)","(23.7836544,90.3786596)","(23.783038,90.3788851)","(23.7824754,90.3790914)","(23.7819462,90.3791886)","(23.7813288,90.3793983)","(23.7807312,90.3795501)","(23.780129,90.3797102)","(23.779555,90.3798505)","(23.7789801,90.3799643)","(23.7784058,90.3801815)","(23.777832,90.3803535)","(23.7772572,90.3805425)","(23.7766908,90.3807588)","(23.7761017,90.3809182)","(23.7755185,90.3810851)","(23.7749356,90.3812529)","(23.7743657,90.3814399)","(23.7737864,90.381609)","(23.7732795,90.3817652)","(23.772649,90.3819479)","(23.7720179,90.3821284)","(23.7714401,90.3822858)","(23.7709059,90.382429)","(23.7703238,90.3825959)","(23.7697419,90.3827075)","(23.7691701,90.382799)","(23.76864,90.3828842)","(23.7679946,90.3829783)","(23.7674629,90.3830318)","(23.7668189,90.3831247)","(23.7662188,90.3832102)","(23.7656901,90.383382)","(23.7651926,90.3835734)","(23.7651514,90.3841999)","(23.765068,90.3848559)","(23.7649717,90.3854521)","(23.7648763,90.3860475)","(23.7647758,90.3866427)","(23.7646616,90.3872542)","(23.7645783,90.3877482)","(23.7645113,90.3882346)","(23.764429,90.3890248)","(23.7639508,90.3890952)","(23.7634054,90.3891387)","(23.7629034,90.3891803)","(23.762404,90.3892247)","(23.7618743,90.3892883)","(23.761369,90.3893633)","(23.760848,90.3894467)","(23.7603002,90.3895434)","(23.7597569,90.389673)","(23.7592777,90.3897953)","(23.7587639,90.3899428)","(23.7582396,90.3901293)","(23.7578096,90.3902957)","(23.757118,90.3905336)","(23.7566827,90.390683)","(23.7562323,90.3908566)","(23.7554575,90.3911406)","(23.755009,90.3913162)","(23.7542739,90.3916057)","(23.7538178,90.3917907)","(23.7533983,90.3919724)","(23.7527333,90.3922449)","(23.7522175,90.3924804)","(23.7517647,90.3926413)","(23.7511825,90.3928561)","(23.7505336,90.3931283)","(23.7500063,90.3932702)","(23.7493985,90.3935039)","(23.7489704,90.3936824)","(23.7484938,90.3938596)","(23.7477086,90.3941233)","(23.7472741,90.3942601)","(23.7464386,90.3945224)","(23.7456168,90.3948329)","(23.7451748,90.3949955)","(23.7444266,90.3952392)","(23.7438582,90.3954018)","(23.7434135,90.3955548)","(23.7429716,90.395692)","(23.7424008,90.3958397)","(23.7416945,90.3959622)","(23.741141,90.3960694)","(23.7403955,90.3961024)","(23.7398687,90.3960832)","(23.7390707,90.3960402)","(23.7386175,90.396007)","(23.7381641,90.3959326)","(23.7373554,90.3957713)","(23.7368436,90.3956601)","(23.7360812,90.3955555)","(23.7355005,90.3955297)","(23.7348035,90.3955056)","(23.7342153,90.3955151)","(23.7337502,90.3955432)","(23.7331283,90.3956197)","(23.7325951,90.3958084)","(23.7322943,90.3953039)","(23.7317946,90.3951442)","(23.7312829,90.3953052)","(23.7307791,90.3953602)","(23.7302663,90.3954245)","(23.7297579,90.3954323)","(23.7292597,90.3954309)","(23.7283738,90.3954237)","(23.7279146,90.3954116)","(23.7274532,90.39541)","(23.7266255,90.3954163)","(23.7265643,90.3948799)","(23.7266546,90.394382)","(23.7268576,90.3937756)","(23.7269938,90.3933049)","(23.7271349,90.3927184)","(23.7272578,90.3920702)","(23.7276694,90.3916942)","(23.8282733,90.36396)","(23.8288172,90.3638581)","(23.8292806,90.3638014)","(23.8282203,90.3640091)","(23.8287139,90.3638742)","(23.8292122,90.3638095)","(23.8286883,90.3641201)","(23.8281919,90.3641899)","(23.8275966,90.3642173)","(23.8267811,90.3642605)","(23.8263212,90.36425)","(23.8255487,90.3642441)","(23.8250836,90.3642669)","(23.8246313,90.3643309)","(23.8239349,90.3643745)","(23.8233798,90.3644083)","(23.8227291,90.3644482)","(23.822113,90.3645399)","(23.8215384,90.3646966)","(23.8208484,90.36491)","(23.8203608,90.365077)","(23.8195954,90.3652355)","(23.8187682,90.3653926)","(23.8182923,90.3655415)","(23.8175789,90.3657397)","(23.8170595,90.3658799)","(23.8163953,90.3660607)","(23.8158404,90.3662019)","(23.815217,90.36638)","(23.8145986,90.3665679)","(23.814083,90.3667501)","(23.8133402,90.3669503)","(23.8125797,90.3671485)","(23.8120865,90.3672848)","(23.81129,90.3674969)","(23.8104933,90.3676845)"}	f	0	reyazul	t	\N
2665	2024-03-03 01:27:03.637763+06	4	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-03-03 01:54:27.275+06\\")"}	from_buet	Ba-63-1146	t	jahangir	nazmul	2024-03-03 02:18:43.858504+06	(37.4219983,-122.084)	(23.7353203,90.3843313)	{"(37.4219983,-122.084)","(23.7649149,90.3632413)","(23.7644469,90.3634556)","(23.7639119,90.363654)","(23.7638818,90.3641442)","(23.7634079,90.3642939)","(23.7628317,90.36449)","(23.7623508,90.3646595)","(23.7617892,90.3648555)","(23.7613036,90.3650171)","(23.7607361,90.3652085)","(23.7602726,90.3654121)","(23.759711,90.365586)","(23.759216,90.3654901)","(23.7589484,90.3648462)","(23.7587124,90.3643826)","(23.7583797,90.3637528)","(23.7579156,90.3635064)","(23.757366,90.3637669)","(23.7568309,90.3639379)","(23.7562987,90.3641087)","(23.7557375,90.364298)","(23.7552168,90.3641979)","(23.7546859,90.3643972)","(23.7542287,90.3649719)","(23.7538569,90.3653933)","(23.7533819,90.3659429)","(23.7530157,90.3663793)","(23.7525215,90.366958)","(23.752138,90.3673448)","(23.7515669,90.3677721)","(23.7511231,90.3680884)","(23.7505367,90.3684907)","(23.7500635,90.3688151)","(23.7494883,90.369215)","(23.7490297,90.3695352)","(23.7484406,90.369943)","(23.747982,90.3702499)","(23.7474226,90.3706232)","(23.7469486,90.370945)","(23.7463554,90.371355)","(23.7459038,90.3716529)","(23.7453182,90.3720477)","(23.7448405,90.3723583)","(23.7442418,90.3727402)","(23.7437921,90.3730499)","(23.7432263,90.3734402)","(23.7427571,90.3737516)","(23.7421406,90.3740942)","(23.7416519,90.3743363)","(23.7410231,90.3746736)","(23.7405324,90.374912)","(23.7398946,90.3752261)","(23.7393918,90.3754899)","(23.7388075,90.3757947)","(23.7383972,90.3761895)","(23.7384674,90.3769466)","(23.7385373,90.377442)","(23.7386197,90.3780746)","(23.7387171,90.3787978)","(23.7388284,90.3794178)","(23.7389246,90.3798972)","(23.7390473,90.3805763)","(23.7395511,90.3807861)","(23.7400107,90.3806662)","(23.7402481,90.3812574)","(23.7403565,90.3818044)","(23.7404636,90.3823695)","(23.7405677,90.3829196)","(23.7402003,90.3832126)","(23.7397368,90.3832833)","(23.739292,90.3833814)","(23.738808,90.3834828)","(23.7383627,90.3835902)","(23.7378978,90.3837366)","(23.7374485,90.3838406)","(23.7369944,90.383937)","(23.7365435,90.384029)","(23.7360664,90.3841315)","(23.7355998,90.3842491)","(23.7351045,90.3843884)","(23.7345071,90.3845451)","(23.7338787,90.3846883)","(23.7332652,90.38486)","(23.7327113,90.3850769)","(23.7324815,90.3855848)","(23.732533,90.3862516)","(23.732625,90.3869148)","(23.7321027,90.3870118)","(23.7316097,90.3869603)","(23.731053,90.3870352)","(23.7305831,90.3871742)","(23.7300977,90.3873612)","(23.7296659,90.3875803)","(23.7292406,90.3878891)","(23.7288626,90.3882101)","(23.7284657,90.3885823)","(23.7281111,90.3889468)","(23.727742,90.3893166)","(23.7274356,90.3896776)","(23.7275762,90.3901579)","(23.7276986,90.3906461)","(23.7278564,90.3911119)","(23.7280352,90.3916015)","(23.7275305,90.3917068)","(23.7647317,90.3623417)","(23.7648179,90.3629103)","(23.7646777,90.3633882)","(23.7642223,90.3635384)","(23.7638008,90.3637903)","(23.7634939,90.3642641)","(23.7630318,90.3644287)","(23.7624542,90.3646202)","(23.7619924,90.3647891)","(23.7615592,90.3649445)","(23.7609882,90.3651267)","(23.7605199,90.3653098)","(23.7599442,90.3655185)","(23.759466,90.365656)","(23.7591194,90.3652571)","(23.7589228,90.3647981)","(23.7586097,90.3641766)","(23.7583731,90.3637379)","(23.7579423,90.3635356)","(23.7574024,90.3637463)","(23.7568607,90.3639205)","(23.7563201,90.3641018)","(23.7557851,90.36428)","(23.7552525,90.3641833)","(23.7547689,90.3642816)","(23.7544423,90.3647038)","(23.753942,90.3652949)","(23.7536244,90.365663)","(23.7530994,90.3662774)","(23.7527685,90.366674)","(23.7522403,90.3672691)","(23.751857,90.3675546)","(23.7512281,90.3680168)","(23.7508358,90.3682829)","(23.7501688,90.3687416)","(23.7497731,90.369017)","(23.7490993,90.3694871)","(23.7483935,90.3699719)","(23.7476891,90.3704465)","(23.7470186,90.3708981)","(23.7462594,90.3714147)","(23.7455546,90.3718874)","(23.7449169,90.3723199)","(23.7445107,90.3725601)","(23.7438637,90.3730032)","(23.7434565,90.373281)","(23.7427941,90.3737318)","(23.7423922,90.3739668)","(23.741664,90.3743026)","(23.7409316,90.3747204)","(23.7401937,90.3750798)","(23.7394666,90.375442)","(23.7390493,90.3756684)","(23.7383304,90.3760663)","(23.7382394,90.3765913)","(23.7384732,90.3770594)","(23.7385435,90.3775752)","(23.7386785,90.3784412)","(23.7387368,90.3789363)","(23.7389005,90.3797813)","(23.7389935,90.3802753)","(23.7391662,90.3811464)","(23.7395913,90.3808385)","(23.7402309,90.3806153)","(23.7402783,90.3811146)","(23.7403759,90.3818963)","(23.7405146,90.3826328)","(23.740741,90.3833131)","(23.7401702,90.3832459)","(23.7395159,90.3833191)","(23.7388982,90.3834604)","(23.7383019,90.3835957)","(23.7377112,90.3837962)","(23.7370884,90.3839192)","(23.7364657,90.3840448)","(23.735851,90.3841832)"}	f	0	farid99	t	\N
2662	2024-03-03 01:27:35.686334+06	3	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-03-03 01:55:03.169+06\\")"}	from_buet	BA-11-1234	t	monu67	nazmul	2024-03-03 02:18:44.012531+06	(37.4219983,-122.084)	(23.7356076,90.3842485)	{"(37.4219983,-122.084)","(23.7648724,90.3630939)","(23.7644695,90.3634473)","(23.7640391,90.3636077)","(23.7638814,90.3641148)","(23.7633476,90.364318)","(23.7628636,90.3644807)","(23.762307,90.3646753)","(23.7618068,90.3648501)","(23.761261,90.3650299)","(23.7607535,90.3652019)","(23.7602289,90.3654277)","(23.7597084,90.3655867)","(23.7591696,90.3654394)","(23.7589614,90.3648819)","(23.758655,90.3642782)","(23.7583985,90.3637835)","(23.7580301,90.3634117)","(23.7576302,90.3636609)","(23.7570984,90.36385)","(23.7565664,90.364025)","(23.7559763,90.3642146)","(23.7554406,90.3643112)","(23.7549848,90.3640296)","(23.7546062,90.3644976)","(23.7541666,90.3650338)","(23.7537755,90.3654882)","(23.7533058,90.3660328)","(23.7529364,90.3664751)","(23.7524555,90.3670363)","(23.7520754,90.3673985)","(23.751463,90.3678461)","(23.7510227,90.3681575)","(23.7504488,90.3685507)","(23.749999,90.3688594)","(23.7494053,90.3692716)","(23.7489661,90.3695793)","(23.7483696,90.3699902)","(23.7479169,90.3702942)","(23.7473018,90.3707083)","(23.7468488,90.3710122)","(23.7462592,90.3714145)","(23.7458039,90.3717205)","(23.7452001,90.3721282)","(23.7447754,90.3723977)","(23.744109,90.3728362)","(23.7434212,90.3733059)","(23.7430131,90.3735832)","(23.7423538,90.3739852)","(23.7419034,90.3741917)","(23.7411953,90.3745819)","(23.7407837,90.3747875)","(23.7401055,90.3751221)","(23.7396903,90.3753294)","(23.7389369,90.3757286)","(23.7383749,90.3763214)","(23.7385055,90.3772342)","(23.7386298,90.3781334)","(23.7387558,90.3790452)","(23.7389336,90.3799495)","(23.7391124,90.3808701)","(23.7397245,90.3807319)","(23.7402058,90.3808884)","(23.7403286,90.3816711)","(23.740477,90.3824145)","(23.7406146,90.3831607)","(23.7400491,90.3832327)","(23.7394315,90.3833586)","(23.7388049,90.3834991)","(23.738205,90.3836419)","(23.7375978,90.3838087)","(23.7369755,90.3839426)","(23.7363507,90.384066)","(23.7357359,90.384215)","(23.735142,90.3843787)","(23.7345311,90.3845416)","(23.7339212,90.3846722)","(23.7334786,90.3847984)","(23.7329936,90.3849302)","(23.7324529,90.3852131)","(23.7324875,90.3857199)","(23.7325464,90.3863516)","(23.732618,90.3868693)","(23.7321317,90.3870224)","(23.7316272,90.3869615)","(23.7311267,90.3869661)","(23.7306677,90.3871274)","(23.7302257,90.3872994)","(23.7297467,90.3875202)","(23.7293105,90.387802)","(23.7289402,90.3881318)","(23.7285721,90.3884766)","(23.7281833,90.3888631)","(23.7278383,90.3892241)","(23.7274451,90.3896361)","(23.7275823,90.3901819)","(23.727717,90.3907057)","(23.7278878,90.3911907)","(23.7280511,90.3916636)","(23.7275909,90.3917006)","(23.7646967,90.3622133)","(23.7647843,90.3627949)","(23.7648363,90.3633202)","(23.7643257,90.3634986)","(23.763819,90.3636853)","(23.7636965,90.3642017)","(23.7631818,90.3643755)","(23.7626643,90.3645467)","(23.7621262,90.3647414)","(23.7616223,90.3649167)","(23.7610899,90.3650895)","(23.7605771,90.3652807)","(23.7600383,90.36549)","(23.7595272,90.3656397)","(23.7591183,90.3652922)","(23.7588797,90.3647122)","(23.7586125,90.3641739)","(23.7583017,90.3636034)","(23.7578065,90.36359)","(23.7572765,90.3637877)","(23.7567246,90.3639705)","(23.7561757,90.3641467)","(23.7556406,90.3643194)","(23.7551452,90.3640752)","(23.7546305,90.364467)","(23.7542381,90.3649591)","(23.7538002,90.36546)","(23.7533921,90.3659317)","(23.7529619,90.3664448)","(23.7525598,90.3669148)","(23.7520681,90.3673989)","(23.7515902,90.3677595)","(23.7510184,90.3681591)","(23.7505849,90.3684556)","(23.7499663,90.3688827)","(23.7495055,90.3692036)","(23.748924,90.3696077)","(23.7484884,90.3699078)","(23.7478735,90.3703226)","(23.7474309,90.3706199)","(23.7467989,90.3710465)","(23.7463688,90.371344)","(23.7457281,90.3717715)","(23.7453099,90.3720541)","(23.7446697,90.3724614)","(23.7442573,90.3727372)","(23.7436297,90.3731603)","(23.7432098,90.3734536)","(23.7425785,90.3738706)","(23.7421528,90.3740782)","(23.7414586,90.3744501)","(23.7410365,90.3746604)","(23.7403452,90.3750066)","(23.7399088,90.3752178)","(23.7392098,90.3755897)","(23.7387837,90.3758112)","(23.7384034,90.3765024)","(23.7385269,90.3774164)","(23.7386581,90.3783584)","(23.7387917,90.37926)","(23.7389032,90.3797784)","(23.7390566,90.380617)","(23.7395335,90.3808326)","(23.7401728,90.3806283)","(23.7402238,90.381128)","(23.740361,90.3818266)","(23.7405017,90.3825643)","(23.7407094,90.383258)","(23.7402252,90.383229)","(23.7395759,90.3833108)","(23.7389717,90.383451)","(23.7383591,90.3835739)","(23.7377673,90.3837799)","(23.7371513,90.3839095)","(23.7365241,90.3840346)","(23.735909,90.3841701)","(23.7354308,90.3843023)"}	f	0	zahir53	t	\N
2676	2024-03-03 01:25:41.07105+06	1	afternoon	{NULL,NULL,NULL,NULL,"(5,\\"2024-03-03 01:32:02.583+06\\")","(6,\\"2024-03-03 01:34:41.532+06\\")",NULL,NULL,NULL,NULL,"(11,\\"2024-03-03 01:52:51.477+06\\")",NULL}	from_buet	Ba-46-1334	t	kamaluddin	nazmul	2024-03-03 02:18:44.138767+06	(23.8742717,90.3859033)	(23.8697519,90.400498)	{"(23.8742721,90.3859269)","(23.8742783,90.3864814)","(23.8742859,90.3870123)","(23.874295,90.3875816)","(23.8743101,90.3883147)","(23.8743238,90.3888071)","(23.8743435,90.3894298)","(23.8743534,90.3901794)","(23.8743697,90.3909414)","(23.8743874,90.3916978)","(23.8743923,90.3924078)","(23.87439,90.3931326)","(23.8743996,90.3936476)","(23.8744098,90.394177)","(23.8744415,90.3947514)","(23.8744645,90.3952834)","(23.8744917,90.3958944)","(23.8745234,90.3966041)","(23.8745584,90.3973831)","(23.8746036,90.3981366)","(23.8746152,90.3988923)","(23.8746211,90.3995872)","(23.8746307,90.400319)","(23.8742156,90.4006836)","(23.873569,90.4007014)","(23.8729797,90.4007241)","(23.8723194,90.400697)","(23.8718671,90.4006685)","(23.8713324,90.4006346)","(23.8705762,90.4005852)","(23.8701159,90.4005345)","(23.8693161,90.4004601)","(23.868463,90.4003827)","(23.8679663,90.4003741)","(23.8672688,90.4003504)","(23.8666918,90.40032)","(23.8660519,90.4002944)","(23.8653868,90.4002425)","(23.864831,90.4001831)","(23.8641246,90.4001497)","(23.8636306,90.4001316)","(23.8625266,90.4000054)","(23.8616156,90.3998936)","(23.8606955,90.4001958)","(23.8598819,90.4006992)","(23.8591592,90.4013298)","(23.8585497,90.4018971)","(23.8579394,90.4024617)","(23.8572342,90.4030277)","(23.8567157,90.4034718)","(23.8560265,90.4041125)","(23.8553808,90.4046054)","(23.8547281,90.4051149)","(23.8541034,90.405648)","(23.8534545,90.4061405)","(23.8528879,90.4066857)","(23.8523336,90.4071333)","(23.8516671,90.4076974)","(23.8510467,90.4082252)","(23.8504061,90.4087014)","(23.8498021,90.4091508)","(23.8492661,90.4096682)","(23.8485942,90.4102142)","(23.8479761,90.4107124)","(23.8473958,90.4111817)","(23.846728,90.4117307)","(23.8461237,90.4122261)","(23.8456638,90.4126039)","(23.844978,90.4132008)","(23.8443703,90.4136828)","(23.8436228,90.4153521)","(23.8421165,90.4164748)","(23.8409364,90.4173267)","(23.8395137,90.4186449)","(23.8380393,90.4192174)","(23.8366058,90.4194272)","(23.8348742,90.4196759)","(23.8332808,90.4198879)","(23.831652,90.4201577)","(23.8300484,90.4204013)","(23.8284276,90.4207196)","(23.8270295,90.4213197)","(23.8256371,90.4219893)","(23.8240109,90.422416)","(23.8224369,90.4221977)","(23.8209273,90.4213173)","(23.8196135,90.4204517)","(23.8190067,90.4187757)","(23.8188137,90.416578)","(23.8187529,90.4148665)","(23.8174579,90.4135774)","(23.8162322,90.4123312)","(23.8152908,90.4107865)","(23.8144882,90.4093181)","(23.8138838,90.4079398)","(23.8128627,90.4061792)","(23.811893,90.4048793)","(23.8106927,90.4037676)","(23.8093176,90.4031912)","(23.8077174,90.4028586)","(23.8059757,90.4026161)","(23.8044164,90.4023569)","(23.8028074,90.4020971)","(23.8011867,90.4018486)","(23.7996229,90.4016153)","(23.7980196,90.4013066)","(23.7964691,90.4009667)","(23.7951056,90.4006303)","(23.7933889,90.4003049)","(23.791729,90.400031)","(23.790069,90.399755)","(23.7884255,90.3994783)","(23.7868438,90.3992329)","(23.7853512,90.3990109)","(23.7837419,90.3987474)","(23.7821734,90.3984735)","(23.780578,90.39823)","(23.7789185,90.3979596)","(23.7773365,90.3977119)","(23.7757043,90.3974012)","(23.7743131,90.3972154)","(23.7724973,90.3968804)","(23.7708789,90.3966342)","(23.7693202,90.3963618)","(23.7679128,90.3961173)","(23.7661673,90.3956819)","(23.7645748,90.3952633)","(23.7633853,90.3950583)","(23.7621435,90.3949211)","(23.7609125,90.3948081)","(23.7596561,90.3946192)","(23.7583457,90.3944049)","(23.7573071,90.3939822)","(23.7574457,90.3927007)","(23.7579043,90.3914102)","(23.7585272,90.3901289)","(23.7585012,90.3885988)","(23.7583002,90.387184)","(23.7578202,90.3860151)","(23.7581889,90.3853933)","(23.758131,90.3847847)","(23.7580714,90.3841701)","(23.7581881,90.3835649)","(23.7586597,90.3833399)","(23.7585053,90.3824413)","(23.7584729,90.3816659)","(23.7584453,90.3808269)","(23.7584117,90.3800522)","(23.7583605,90.3792605)","(23.7583183,90.3784198)","(23.7582783,90.3776964)","(23.7582629,90.3768601)","(23.7582499,90.3760086)","(23.75823,90.3751697)","(23.757916,90.3744414)","(23.7571309,90.3748702)","(23.7564358,90.375286)","(23.7559913,90.3755484)","(23.7553311,90.3759376)","(23.7548005,90.3762749)","(23.7542471,90.3766188)","(23.7536548,90.3769219)","(23.7532453,90.3771516)","(23.7527606,90.3773939)","(23.7520451,90.3778128)","(23.7516362,90.3780556)","(23.7508807,90.3784858)","(23.750214,90.378868)","(23.7498106,90.3791159)","(23.7494002,90.37937)","(23.7489958,90.3796101)","(23.7485824,90.3798483)","(23.7481794,90.380075)","(23.7477734,90.3803133)","(23.7473766,90.3805616)","(23.7468449,90.3808752)","(23.7462287,90.381225)","(23.7457323,90.3815174)","(23.7450653,90.3819018)","(23.744603,90.3821259)","(23.7438202,90.3822968)","(23.7433743,90.3824045)","(23.7425369,90.3826167)","(23.7417378,90.3828056)","(23.7412774,90.3829378)","(23.7405253,90.3831469)","(23.7400454,90.3832307)","(23.7395932,90.3833199)","(23.7389384,90.3834509)","(23.7384899,90.3835498)","(23.7378469,90.3837481)","(23.7373971,90.3838535)","(23.7368355,90.383971)","(23.7361184,90.3841199)","(23.7356702,90.3842316)","(23.7352139,90.3843589)","(23.734375,90.384572)","(23.7335555,90.3847804)","(23.7331165,90.3848981)","(23.7325862,90.3852783)","(23.7324947,90.385815)","(23.732562,90.3864488)","(23.7326284,90.3869466)","(23.7320643,90.3869773)","(23.7315129,90.3869641)","(23.7309908,90.3870484)","(23.874255,90.3850683)","(23.87427,90.3857948)","(23.87428,90.3865898)","(23.8742901,90.3873649)","(23.87431,90.388101)","(23.8743201,90.3887714)","(23.8743518,90.3895203)","(23.8743557,90.3902373)","(23.8743614,90.3909592)","(23.8743803,90.3914797)","(23.8743859,90.3920404)","(23.8743901,90.392554)","(23.874388,90.3931097)","(23.8743996,90.3936476)","(23.8744152,90.3943898)","(23.8744601,90.3951832)","(23.874495,90.3959658)","(23.8745288,90.3966978)","(23.8745625,90.3973873)","(23.8746095,90.3981057)","(23.8746149,90.3988186)","(23.87462,90.3993113)","(23.87462,90.3999117)","(23.8746355,90.400447)","(23.8742262,90.4006865)","(23.8735688,90.4007015)","(23.8730276,90.4007234)","(23.8723191,90.400697)","(23.8717823,90.4006639)","(23.8710137,90.4006199)","(23.8702072,90.4005453)","(23.8697556,90.4004983)"}	f	0	jamal7898	t	\N
3359	2024-04-22 18:43:16.568559+06	6	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-63-1146	t	altaf	nazmul	2024-03-04 18:45:34.513374+06	(23.831858,90.3532122)	(23.8318519,90.3532511)	{"(23.831858,90.3532122)","(23.8318638,90.3532133)","(23.831866,90.35321)","(23.8318655,90.3532192)","(23.8318519,90.3532511)"}	f	39	zahir53	t	{"2024-03-04 18:43:16.568+06","2024-03-04 18:43:28.089+06","2024-03-04 18:43:50.693+06","2024-03-04 18:44:52.915+06","2024-03-04 18:45:33.626+06"}
2655	2024-03-03 15:10:17.707177+06	5	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-20-3066	t	shahid88	nazmul	2024-03-03 15:17:28.046504+06	(23.76614,90.3649067)	(23.7665367,90.364725)	{"(23.7661157,90.3649147)","(23.7655546,90.3651241)","(23.7649241,90.365355)","(23.7644712,90.3655011)","(23.7641584,90.3651013)","(23.7639979,90.3645125)","(23.7638667,90.3640302)","(23.7636919,90.3634078)","(23.7635196,90.3628182)","(23.7633404,90.3622104)","(23.7631511,90.3615991)","(23.7629762,90.3610335)","(23.7628335,90.3604418)","(23.7626664,90.3598603)","(23.7625157,90.3593095)","(23.7622225,90.3588389)","(23.7617304,90.3589051)","(23.7612671,90.3589304)","(23.7607933,90.3589185)","(23.7602893,90.3588949)","(23.7597921,90.3589772)","(23.7593064,90.3591714)","(23.758884,90.3593998)","(23.7665367,90.364725)"}	f	0	nasir81	t	\N
2610	2024-02-29 01:25:45.266797+06	2	evening	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-03-03 01:53:10.689+06\\")"}	from_buet	Ba-48-5757	t	nizam88	\N	2024-03-03 02:18:45.379573+06	(37.4219983,-122.084)	(23.7355174,90.3842748)	{"(37.4219983,-122.084)","(23.7648632,90.3630609)","(23.7644962,90.363439)","(23.7640681,90.3635965)","(23.7638728,90.3640654)","(23.7633914,90.3642996)","(23.7629068,90.3644673)","(23.7623523,90.3646596)","(23.7618501,90.3648351)","(23.7613051,90.3650175)","(23.7607968,90.3651885)","(23.7603786,90.3653761)","(23.7598394,90.3655489)","(23.7592966,90.3656646)","(23.7590409,90.3650722)","(23.7588067,90.3645659)","(23.7585201,90.3640047)","(23.7582433,90.3634953)","(23.7577094,90.3636295)","(23.757269,90.3637921)","(23.7567301,90.3639532)","(23.7561864,90.3641432)","(23.7556533,90.3643271)","(23.7551643,90.3641184)","(23.7546646,90.3644047)","(23.7542524,90.3649343)","(23.7538377,90.3654168)","(23.7533924,90.365931)","(23.7529977,90.3664011)","(23.752569,90.3669046)","(23.7521142,90.3673905)","(23.7515997,90.3677484)","(23.7510971,90.3681082)","(23.7505602,90.3684731)","(23.7500372,90.3688348)","(23.7495103,90.3691983)","(23.7490055,90.3695537)","(23.7484635,90.3699251)","(23.7479559,90.3702664)","(23.7474406,90.3706139)","(23.7469239,90.3709622)","(23.7463785,90.3713351)","(23.745986,90.3715952)","(23.7455273,90.3719067)","(23.7449502,90.3722931)","(23.7444417,90.3726059)","(23.7438621,90.3730031)","(23.743431,90.3732976)","(23.7427919,90.3737285)","(23.7423705,90.3739815)","(23.7416911,90.374316)","(23.7412455,90.3745564)","(23.7406077,90.3748752)","(23.7401203,90.3751164)","(23.7394652,90.3754495)","(23.738986,90.3757024)","(23.7384135,90.3761313)","(23.7384252,90.3766427)","(23.7384996,90.3771713)","(23.7386048,90.3779807)","(23.7386812,90.3785263)","(23.7388197,90.3793685)","(23.7389247,90.3798864)","(23.7390735,90.380694)","(23.7396278,90.3807561)","(23.7401629,90.3807886)","(23.740307,90.3815605)","(23.7404567,90.3823283)","(23.7406121,90.3830414)","(23.7401024,90.3832217)","(23.7394668,90.3833443)","(23.7388698,90.3834701)","(23.7382571,90.3836278)","(23.73765,90.383794)","(23.7370269,90.3839301)","(23.7364035,90.3840551)","(23.7357884,90.3842016)","(23.7351632,90.3843727)","(23.7345499,90.3845369)","(23.7339562,90.3846697)","(23.7333236,90.384842)","(23.7327542,90.3850299)","(23.7324704,90.3855171)","(23.7325159,90.386181)","(23.7326143,90.3868405)","(23.732119,90.3872602)","(23.7317222,90.3869428)","(23.7312323,90.3869044)","(23.7307301,90.3870763)","(23.7302764,90.3872652)","(23.72979,90.387494)","(23.7293973,90.3877416)","(23.7289607,90.3880978)","(23.7285866,90.3884514)","(23.7282221,90.3888228)","(23.7278803,90.3891831)","(23.727505,90.3895558)","(23.7271134,90.3898183)","(23.727527,90.3900523)","(23.7276718,90.3905558)","(23.7278347,90.3910438)","(23.7280099,90.391533)","(23.7274132,90.3917104)","(23.7647317,90.3623417)","(23.7648175,90.3629105)","(23.7649643,90.363409)","(23.7644696,90.3634473)","(23.7639618,90.363635)","(23.7639345,90.3642879)","(23.7633615,90.3643111)","(23.7628853,90.364474)","(23.7623207,90.36467)","(23.7618285,90.3648434)","(23.7612743,90.3650275)","(23.7607752,90.3651952)","(23.7602424,90.3654242)","(23.7597302,90.3655801)","(23.7591761,90.365468)","(23.7589796,90.3649201)","(23.7586661,90.3643008)","(23.7584169,90.3638185)","(23.7580477,90.3634009)","(23.7575123,90.3637086)","(23.7569682,90.3638942)","(23.7564247,90.3640719)","(23.7558811,90.3642471)","(23.7553508,90.3642975)","(23.7549035,90.3640767)","(23.7546223,90.3644752)","(23.754195,90.3650021)","(23.7538856,90.3653595)","(23.7534974,90.3658099)","(23.7530457,90.366344)","(23.7526819,90.3667745)","(23.7522042,90.3672957)","(23.7517529,90.3676343)","(23.7511932,90.3680401)","(23.7507264,90.3683593)","(23.7501338,90.3687666)","(23.749677,90.369084)","(23.7490998,90.3694869)","(23.7486304,90.369811)","(23.7480515,90.3702036)","(23.7475742,90.3705242)","(23.7469835,90.3709217)","(23.7465467,90.3712199)","(23.7459401,90.3716299)","(23.7454734,90.3719433)","(23.7449119,90.3723157)","(23.7444298,90.3726052)","(23.743861,90.3730038)","(23.7433779,90.3733356)","(23.7427921,90.3737283)","(23.7423087,90.3740124)","(23.7416891,90.3743165)","(23.7412271,90.3745657)","(23.740573,90.3748929)","(23.7401008,90.3751241)","(23.7394652,90.3754495)","(23.7389676,90.3757123)","(23.7384118,90.3761324)","(23.7384315,90.3767419)","(23.7385336,90.3774865)","(23.7386192,90.3780806)","(23.7387188,90.3788508)","(23.7388358,90.3794571)","(23.7389853,90.38023)","(23.739102,90.3808348)","(23.7395962,90.3807625)","(23.7401523,90.3807531)","(23.740246,90.3812477)","(23.7403654,90.3818606)","(23.7404664,90.3823721)","(23.7405957,90.3830073)","(23.7401325,90.3832162)","(23.7394981,90.3833377)","(23.7388859,90.3834665)","(23.7382874,90.3836179)","(23.7376817,90.3837872)","(23.7370278,90.38393)","(23.7364033,90.3840551)","(23.7357884,90.3842016)"}	f	0	siddiq2	t	\N
3374	2024-04-22 15:11:12.451974+06	5	morning	{"(36,\\"2024-03-04 12:30:00+06\\")","(37,\\"2024-03-04 12:33:00+06\\")","(38,\\"2024-03-04 12:40:00+06\\")","(39,\\"2024-03-04 12:45:00+06\\")","(40,\\"2024-03-04 12:50:00+06\\")","(70,\\"2024-03-04 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	ibrahim	nazmul	2024-04-22 23:58:36.844426+06	(23.76631,90.3648517)	(23.760405,90.372915)	{"(23.760405,90.372915)"}	f	104	rashid56	t	{"2024-04-22 23:58:11.301+06"}
3375	2024-04-22 23:46:34.621639+06	5	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	2024-04-22 23:47:46.945607+06	(37.4219983,-122.084)	(37.4219983,-122.084)	{"(37.4219983,-122.084)","(37.4219983,-122.084)"}	f	62	mahbub777	t	{"2024-04-22 23:46:34.621+06","2024-04-22 23:46:37.254+06"}
2311	2024-02-07 16:05:13.253608+06	3	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-35-1461	t	altaf	nazmul	2024-02-07 16:06:07.078519+06	(23.7626809,90.3702142)	(23.7626744,90.3702182)	{"(23.762687,90.3702104)"}	f	0	mahbub777	t	\N
2312	2024-02-07 16:07:02.122946+06	3	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-35-1461	t	altaf	nazmul	2024-02-07 16:07:08.64287+06	(23.7626882,90.3702101)	(23.7626864,90.3702097)	{"(23.7626864,90.3702097)"}	f	0	mahbub777	t	\N
2054	2024-02-09 11:03:21.063747+06	5	afternoon	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 11:03:25.977+06\\")"}	from_buet	Ba-22-4326	t	rashed3	nazmul	2024-02-09 11:04:26.010806+06	(23.7276,90.3917)	(23.7275675,90.3917006)	{"(23.7275743,90.3917007)"}	f	0	ASADUZZAMAN	t	\N
2313	2024-02-07 16:12:57.532015+06	3	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-35-1461	t	altaf	nazmul	2024-02-07 17:53:05.068558+06	(23.762676,90.3702415)	(23.762682,90.3702159)	{"(23.7626869,90.3702193)","(23.7626855,90.3702076)","(23.7626792,90.3702124)","(23.7626759,90.3702081)"}	f	2	mahbub777	t	\N
2017	2024-02-09 11:05:15.057455+06	8	morning	{NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 11:05:20.022+06\\")"}	to_buet	Ba-85-4722	t	rashed3	\N	2024-02-09 11:06:04.0196+06	(23.7276,90.3917)	(23.7275686,90.3917004)	{"(23.7275743,90.3917007)"}	f	0	rashid56	t	\N
2055	2024-02-09 11:06:56.017838+06	5	evening	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 11:07:00.975+06\\")"}	from_buet	Ba-22-4326	t	rashed3	nazmul	2024-02-09 11:08:27.202194+06	(23.7276,90.3917)	(23.7275685,90.3917004)	{"(23.7275743,90.3917007)"}	f	0	ASADUZZAMAN	t	\N
2504	2024-02-12 15:45:04.590065+06	7	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-97-6734	t	ibrahim	\N	2024-02-12 15:47:11.851846+06	(23.76381,90.3638183)	(23.7267143,90.3881637)	{"(23.76381,90.36381833333333)","(23.7267046,90.3881272)"}	f	1	khairul	t	\N
2373	2024-02-13 15:49:57.664267+06	5	evening	{"(36,\\"2024-02-12 15:50:56.132+06\\")",NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-83-8014	t	ibrahim	\N	2024-02-12 15:52:10.102074+06	(23.76381,90.3638183)	(23.7633437,90.3622208)	{"(23.76381,90.36381833333333)","(23.76715,90.36451)","(23.76672,90.36466166666666)","(23.765975,90.36496833333334)","(23.76521,90.36526)","(23.76451,90.36548333333333)","(23.764155,90.36505833333334)","(23.763988333333334,90.36447833333334)","(23.76381,90.36381833333333)","(23.763631666666665,90.36321)","(23.763453333333334,90.36257833333333)"}	f	0	alamgir	t	\N
2654	2024-03-03 15:17:45.702343+06	5	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-20-3066	t	shahid88	nazmul	2024-03-03 15:33:18.022966+06	(23.765797,90.3650337)	(23.7450415,90.3722355)	{"(23.7657721,90.365044)","(23.7652071,90.3652602)","(23.7647511,90.3654081)","(23.7641223,90.3656002)","(23.764123,90.3649522)","(23.76395,90.3643401)","(23.7637817,90.3637067)","(23.7635976,90.3630913)","(23.7634301,90.3625002)","(23.7632584,90.3619416)","(23.7630871,90.3613648)","(23.7629157,90.3607769)","(23.7627691,90.3601907)","(23.7626064,90.359641)","(23.7624652,90.3591748)","(23.7621052,90.3588677)","(23.7616035,90.3589103)","(23.7610766,90.3589304)","(23.7605765,90.3588871)","(23.7600526,90.3589181)","(23.7596061,90.3590335)","(23.7591401,90.3592633)","(23.7586968,90.3595013)","(23.7582856,90.359784)","(23.757885,90.360119)","(23.7575327,90.3604915)","(23.7571592,90.3608458)","(23.7570602,90.3613506)","(23.7567376,90.3619452)","(23.7562065,90.362577)","(23.75567,90.363205)","(23.755119,90.3638635)","(23.7546316,90.3644692)","(23.7543102,90.3648698)","(23.7538401,90.3654141)","(23.7534401,90.365875)","(23.75308,90.3663009)","(23.7526304,90.3668318)","(23.7522543,90.3672718)","(23.7516753,90.367695)","(23.7512804,90.3679792)","(23.7506434,90.3684151)","(23.749967,90.3688817)","(23.7492782,90.369361)","(23.7486665,90.3697857)","(23.7482373,90.3700782)","(23.7476703,90.3704597)","(23.7472319,90.370755)","(23.7466825,90.371127)","(23.7461952,90.3714552)","(23.7457028,90.3717882)","(23.7451802,90.3721417)"}	f	0	nasir81	t	\N
2720	2024-03-04 01:15:28.96968+06	6	morning	{"(41,\\"2024-03-04 01:15:34.775+06\\")","(42,\\"2024-03-04 01:16:42.674+06\\")","(43,\\"2024-03-04 01:26:01.188+06\\")","(44,\\"2024-03-04 01:28:17.163+06\\")","(45,\\"2024-03-04 01:29:21.507+06\\")","(46,\\"2024-03-04 01:31:15.997+06\\")","(47,\\"2024-03-04 03:35:03.338+06\\")","(48,\\"2024-03-04 03:35:24.273+06\\")","(49,\\"2024-03-04 03:35:45.807+06\\")",NULL}	to_buet	Ba-97-6734	t	shahid88	nazmul	2024-03-04 03:38:25.812688+06	(23.8070591,90.3688)	(23.73832,90.38361)	{"(23.8068676,90.3686291)","(23.8068585,90.3676967)","(23.8066079,90.3665863)","(23.8062477,90.3656533)","(23.8059102,90.3650404)","(23.8055269,90.3643702)","(23.8051267,90.3636819)","(23.8047734,90.3630144)","(23.8045177,90.3625671)","(23.80416,90.3620506)","(23.8038866,90.3616512)","(23.8034995,90.3610984)","(23.8030938,90.3604541)","(23.8035597,90.3608945)","(23.8038202,90.3613123)","(23.8042564,90.3620065)","(23.8047416,90.3627431)","(23.8051618,90.3635107)","(23.8054398,90.3640149)","(23.8058445,90.3646816)","(23.8060974,90.3651564)","(23.8055909,90.3644781)","(23.8053423,90.3640576)","(23.805088,90.3636043)","(23.8046721,90.3628437)","(23.8044186,90.362437)","(23.8038986,90.3616736)","(23.8033919,90.360939)","(23.8029019,90.3601809)","(23.8026022,90.3596805)","(23.8021837,90.359041)","(23.801872,90.3585413)","(23.8014611,90.3578532)","(23.8011967,90.3574427)","(23.800926,90.3570381)","(23.8006536,90.3566127)","(23.8001907,90.3558975)","(23.7998775,90.3555104)","(23.7995301,90.3548402)","(23.7992737,90.3544339)","(23.799017,90.3540287)","(23.7984871,90.35346)","(23.7982702,90.3539563)","(23.7976532,90.3539435)","(23.7975198,90.3534146)","(23.7968818,90.3533608)","(23.7963102,90.353401)","(23.795703,90.353433)","(23.7951707,90.3534795)","(23.7946367,90.3535248)","(23.7940039,90.3535914)","(23.7934027,90.3536515)","(23.7927907,90.3537032)","(23.7922602,90.3537399)","(23.7917003,90.35377)","(23.7910705,90.35382)","(23.7905235,90.3538533)","(23.7899453,90.3538917)","(23.7894052,90.3539233)","(23.7888799,90.35394)","(23.7882707,90.3539417)","(23.7876852,90.35395)","(23.7871051,90.3539714)","(23.7865769,90.3540025)","(23.7860024,90.3540293)","(23.7853622,90.3540003)","(23.7848455,90.3537777)","(23.7843416,90.3534707)","(23.7838252,90.3531397)","(23.783361,90.3528508)","(23.7828297,90.3525293)","(23.7823192,90.3522407)","(23.7818506,90.3520107)","(23.7814305,90.3521963)","(23.7811687,90.3526644)","(23.7809021,90.3531395)","(23.7806403,90.3536346)","(23.7803903,90.3541097)","(23.7801668,90.3545615)","(23.779956,90.3550009)","(23.7797055,90.3554929)","(23.7794452,90.3559616)","(23.80695,90.36828)","(23.8065111,90.3663175)","(23.8056621,90.3645933)","(23.8048317,90.3631128)","(23.8036642,90.3613467)","(23.8048278,90.3628767)","(23.8058251,90.3646478)","(23.8053223,90.3640245)","(23.8041005,90.3619615)","(23.8027833,90.3599917)","(23.8016449,90.3581737)","(23.8005103,90.3563958)","(23.799195,90.3543141)","(23.7980802,90.353961)","(23.7973361,90.3533134)","(23.79422,90.35357)","(23.7917051,90.3537694)","(23.788605,90.35394)","(23.78575,90.35403)","(23.78336,90.35285)","(23.7811988,90.3526222)","(23.7801041,90.3546967)","(23.779065,90.3573867)","(23.7786209,90.3599276)","(23.77736,90.36221)","(23.775895,90.3644)","(23.77439,90.36628)","(23.7720267,90.3677833)","(23.7696333,90.3687033)","(23.7673567,90.3695833)","(23.7652485,90.3704361)","(23.7627083,90.3715733)","(23.7607274,90.3727315)","(23.75853,90.37406)","(23.75636,90.37533)","(23.75404,90.37672)","(23.75176,90.37798)","(23.7495733,90.3792633)","(23.7474233,90.3805317)","(23.74529,90.38178)","(23.7429567,90.38251)","(23.74065,90.38311)","(23.73832,90.38361)"}	f	0	abdulbari4	t	{"2024-03-04 03:36:49.465+06","2024-03-04 03:36:59.946+06","2024-03-04 03:37:10.393+06","2024-03-04 03:37:21.273+06","2024-03-04 03:37:31.716+06","2024-03-04 03:37:42.278+06","2024-03-04 03:37:52.654+06","2024-03-04 03:38:02.786+06","2024-03-04 03:38:12.93+06","2024-03-04 03:38:23.224+06"}
3087	2024-04-22 09:04:33.639583+06	5	afternoon	{"(70,\\"2024-03-04 09:04:35.052+06\\")",NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	2024-03-04 09:06:10.623376+06	(23.7271833,90.3917167)	(23.7267796,90.3902953)	{"(23.7271833,90.3917167)","(23.7271789,90.3917165)","(23.7266053,90.3917249)","(23.7261419,90.3918066)","(23.7262448,90.3910534)","(23.7265613,90.3905938)"}	f	25	mahbub777	t	{"2024-03-04 09:04:33.639+06","2024-03-04 09:04:35.052+06","2024-03-04 09:05:00.096+06","2024-03-04 09:05:21.089+06","2024-03-04 09:05:53.035+06","2024-03-04 09:06:03.095+06"}
2770	2024-04-19 08:35:17.883696+06	6	evening	{"(70,\\"2024-03-04 08:36:32.631+06\\")",NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-48-5757	t	monu67	nazmul	2024-03-04 08:36:37.583187+06	(23.7679334,90.3692308)	(23.7275117,90.391705)	{"(23.7679537,90.3692253)","(23.7686023,90.3689964)","(23.7690718,90.3688154)","(23.7695788,90.368615)","(23.7700574,90.3684239)","(23.7705437,90.3682181)","(23.7710468,90.3680297)","(23.7274877,90.3917054)"}	f	0	zahir53	t	{"2024-03-04 08:35:23.687+06","2024-03-04 08:35:33.68+06","2024-03-04 08:35:43.676+06","2024-03-04 08:35:53.694+06","2024-03-04 08:36:03.696+06","2024-03-04 08:36:13.683+06","2024-03-04 08:36:23.706+06","2024-03-04 08:36:32.631+06"}
2695	2024-03-03 15:41:18.724511+06	5	evening	{"(36,\\"2024-03-03 15:41:51.338+06\\")","(37,\\"2024-03-03 15:49:55.704+06\\")","(38,\\"2024-03-03 15:53:34.843+06\\")","(39,\\"2024-03-03 15:56:32.666+06\\")","(40,\\"2024-03-03 15:59:22.224+06\\")","(70,\\"2024-03-03 16:13:43.329+06\\")"}	from_buet	Ba-63-1146	t	rashed3	nazmul	\N	(23.76614,90.3649067)	\N	{"(23.7661107,90.3649145)","(23.7655125,90.3651389)","(23.7650266,90.365306)","(23.7645667,90.3654541)","(23.7641827,90.3651504)","(23.7640151,90.3645754)","(23.7638501,90.363972)","(23.7636818,90.3633786)","(23.7635117,90.36279)","(23.7633317,90.3621801)","(23.763148,90.361573)","(23.7629713,90.3609687)","(23.762814,90.3603653)","(23.7626425,90.3597723)","(23.7624557,90.3591483)","(23.7620758,90.3588799)","(23.7615802,90.3589117)","(23.761052,90.35893)","(23.7605503,90.3588834)","(23.7600252,90.358925)","(23.7595369,90.3590765)","(23.7590639,90.3593053)","(23.7586052,90.3595652)","(23.7581843,90.3598793)","(23.7577729,90.3602321)","(23.7574006,90.360626)","(23.7571217,90.3610393)","(23.7570098,90.3615896)","(23.7567056,90.3619899)","(23.7562056,90.3625777)","(23.7556704,90.3632046)","(23.7553641,90.3635718)","(23.7548352,90.364213)","(23.7543102,90.3648698)","(23.7539246,90.3653202)","(23.7534785,90.3658315)","(23.7531499,90.3662212)","(23.752633,90.3668283)","(23.7523091,90.3672097)","(23.7517082,90.3676704)","(23.7512951,90.3679604)","(23.7506757,90.3683927)","(23.750024,90.3688427)","(23.7496266,90.3691136)","(23.748977,90.3695697)","(23.7483036,90.3700331)","(23.7475952,90.3705099)","(23.7469018,90.3709766)","(23.7464426,90.3712803)","(23.7458802,90.3716683)","(23.7454286,90.3719621)","(23.7448216,90.3723689)","(23.7444101,90.3726195)","(23.7437506,90.3730778)","(23.7433617,90.3733442)","(23.7427337,90.373768)","(23.7420004,90.3741464)","(23.7412485,90.3745549)","(23.7407093,90.374803)","(23.7401282,90.3751109)","(23.7396326,90.3753456)","(23.7389868,90.3757007)","(23.7385617,90.3759277)","(23.7389341,90.3756147)","(23.7394015,90.3753652)","(23.7388983,90.3757481)","(23.7384665,90.3760345)","(23.7383973,90.3765314)","(23.7384777,90.3770342)","(23.7385777,90.3778177)","(23.7386552,90.3783864)","(23.7387996,90.3792668)","(23.7389031,90.3797775)","(23.7389924,90.3802868)","(23.7390912,90.3807906)","(23.7396915,90.3807384)","(23.7401814,90.3809012)","(23.7403283,90.3816691)","(23.7404784,90.3824432)","(23.740573,90.3830022)","(23.7401414,90.3832089)","(23.7396132,90.3833136)","(23.7389514,90.3834542)","(23.7383211,90.3836095)","(23.7376827,90.3837864)","(23.7370274,90.3839298)","(23.7363721,90.3840599)","(23.735727,90.3842166)","(23.7350735,90.3843966)","(23.734415,90.3845634)","(23.7338021,90.3847091)","(23.7333587,90.3848215)","(23.7328497,90.3849671)","(23.7324728,90.3854453)","(23.7325137,90.3861166)","(23.7326148,90.3868474)","(23.7321601,90.3870107)","(23.731611,90.3869601)","(23.7310524,90.3870364)","(23.730537,90.387193)","(23.7300968,90.3873616)","(23.7296005,90.3876296)","(23.7291604,90.3879547)","(23.7287436,90.3883197)","(23.7283534,90.3886948)","(23.7279634,90.3890949)","(23.7276236,90.3894397)","(23.7272794,90.3897825)","(23.7276145,90.3903616)","(23.7277638,90.3908438)","(23.7279565,90.3913822)","(23.7275612,90.3917005)","(23.7276,90.3917)","(23.7274895,90.3917053)"}	f	4	alamgir	t	{"2024-03-03 15:53:34.843+06","2024-03-03 15:49:55.704+06","2024-03-03 20:42:43.423+06","2024-03-03 23:19:19.017+06"}
3642	2024-04-23 00:06:35.883711+06	5	morning	{"(36,\\"2024-04-23 00:07:40.735+06\\")",NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-23 00:14:25.643161+06	(23.76481,90.36288)	(23.7644917,90.3705817)	{"(23.76481,90.36288)","(23.76481,90.36288)","(23.7649067,90.363365)","(23.7650367,90.3638367)","(23.7651733,90.3643233)","(23.7647817,90.3646)","(23.7643333,90.3647567)","(23.7642067,90.3652533)","(23.76392,90.3656783)","(23.7633383,90.3658633)","(23.76292,90.3662)","(23.7630983,90.3668767)","(23.7632417,90.3674183)","(23.76342,90.36809)","(23.7635983,90.3686933)","(23.7637783,90.3692967)","(23.7639383,90.3698317)","(23.7641183,90.370435)"}	f	0	rashid56	t	{"2024-04-23 00:08:31.023+06","2024-04-23 00:08:40.547+06","2024-04-23 00:08:50.484+06","2024-04-23 00:08:59.562+06","2024-04-23 00:09:08.643+06","2024-04-23 00:09:17.763+06","2024-04-23 00:09:26.885+06","2024-04-23 00:09:36.025+06","2024-04-23 00:09:45.149+06","2024-04-23 00:09:54.306+06"}
3499	2024-04-22 23:49:13.042276+06	5	afternoon	{NULL,NULL,NULL,NULL,NULL,"(36,\\"2024-04-22 23:50:20.104+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	2024-04-22 23:56:09.471666+06	(23.7647733,90.3627533)	(23.760405,90.372915)	{"(23.7647733,90.3627533)","(23.7647733,90.3627533)","(23.7649133,90.363235)","(23.765005,90.3637233)","(23.7651367,90.3641933)","(23.76484,90.36458)","(23.76439,90.3647383)","(23.7641883,90.3651817)","(23.7639817,90.3656567)","(23.7634233,90.3658317)","(23.76293,90.36614)","(23.7630617,90.3667417)","(23.7632233,90.36735)","(23.763385,90.36796)","(23.7635383,90.3684917)","(23.7637383,90.3691617)","(23.7639183,90.369765)","(23.7640783,90.3703017)","(23.7644333,90.3706067)","(23.7649383,90.3703933)","(23.76552,90.37015)","(23.7659933,90.3699617)","(23.7656183,90.3702783)","(23.7651583,90.370465)","(23.7647183,90.3706317)","(23.76429,90.3708)","(23.76386,90.3709717)","(23.7634133,90.37118)","(23.7629767,90.3714167)","(23.7625583,90.3716583)","(23.76213,90.3719)","(23.7617217,90.37213)","(23.7612933,90.3723717)","(23.76087,90.3726383)","(23.7604433,90.3728933)"}	f	101	mahbub777	t	{"2024-04-22 23:54:12.788+06","2024-04-22 23:54:23.727+06","2024-04-22 23:54:35.112+06","2024-04-22 23:54:46.689+06","2024-04-22 23:54:57.828+06","2024-04-22 23:55:09.231+06","2024-04-22 23:55:20.047+06","2024-04-22 23:55:31.385+06","2024-04-22 23:55:42.929+06","2024-04-22 23:55:54.416+06"}
2744	2024-03-04 03:41:00.217171+06	6	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-97-6734	t	shahid88	nazmul	2024-03-04 03:41:06.508025+06	(23.7380664,90.3836811)	(23.7379451,90.3836864)	{"(23.7380206,90.3836855)"}	f	0	abdulbari4	t	{"2024-03-04 03:41:01.205+06"}
2422	2024-02-12 15:57:20.561882+06	5	evening	{"(36,\\"2024-02-12 15:57:48.662+06\\")","(37,\\"2024-02-12 16:05:50.901+06\\")","(38,\\"2024-02-12 16:09:38.121+06\\")","(39,\\"2024-02-12 16:12:38.36+06\\")","(40,\\"2024-02-12 16:15:17.596+06\\")",NULL}	from_buet	Ba-36-1921	t	ibrahim	\N	2024-02-15 18:06:51.957868+06	(23.766355,90.364835)	(23.7640967,90.3648632)	{"(23.76615333333333,90.36490166666667)","(23.76572,90.36506333333334)","(23.765281666666667,90.36522666666667)","(23.76481666666667,90.36538666666667)","(23.764351666666666,90.36553)","(23.764155,90.36505833333334)","(23.764013333333335,90.36456833333334)","(23.763881666666666,90.36408833333333)","(23.763751666666668,90.36361)","(23.763606666666668,90.36312)","(23.76347,90.36263833333334)","(23.763318333333334,90.36214333333334)","(23.76317166666667,90.36167)","(23.763033333333333,90.36119)","(23.762903333333334,90.36070833333333)","(23.76278,90.36023)","(23.762631666666667,90.35973833333334)","(23.76249,90.35925)","(23.762203333333332,90.35887)","(23.76174333333333,90.35890166666667)","(23.76127333333333,90.35893)","(23.76082,90.35892166666666)","(23.760363333333334,90.35889166666666)","(23.759900000000002,90.35895)","(23.75946,90.35911166666666)","(23.75903,90.35932333333334)","(23.75862,90.35955666666666)","(23.758238333333335,90.359835)","(23.757865,90.360135)","(23.757533333333335,90.36049)","(23.757186666666666,90.36081833333333)","(23.757073333333334,90.361295)","(23.756883333333334,90.36175333333334)","(23.75658,90.36215)","(23.756253333333333,90.36252166666667)","(23.75593,90.362895)","(23.755611666666667,90.363275)","(23.75529166666667,90.36365666666667)","(23.754986666666667,90.36402333333334)","(23.75467666666667,90.36441166666667)","(23.754365,90.3648)","(23.75404,90.36518166666667)","(23.753728333333335,90.36554166666667)","(23.75342,90.3659)","(23.753106666666667,90.36626833333334)","(23.752776666666666,90.36666166666667)","(23.752466666666667,90.36702166666667)","(23.752108333333332,90.36736666666667)","(23.751706666666667,90.36767333333333)","(23.75132,90.36795)","(23.75093,90.36821833333333)","(23.75054,90.36848666666667)","(23.75015,90.368755)","(23.749766666666666,90.36902)","(23.749368333333333,90.36929833333333)","(23.748973333333332,90.36957333333334)","(23.748583333333332,90.36984166666667)","(23.748168333333332,90.370125)","(23.747765,90.370395)","(23.74735666666667,90.37067)","(23.746955,90.37094166666667)","(23.746568333333332,90.371205)","(23.74616,90.37147833333333)","(23.745771666666666,90.37174166666667)","(23.74537,90.37201333333333)","(23.744955,90.37229)","(23.74455,90.37254)","(23.744145,90.37281166666666)","(23.743743333333335,90.37308166666666)","(23.743331666666666,90.37337)","(23.74292,90.373645)","(23.74251,90.37390833333333)","(23.742066666666666,90.37411666666667)","(23.74163,90.37435)","(23.741208333333333,90.374575)","(23.740778333333335,90.37479)","(23.740365,90.37499666666666)","(23.739935,90.375205)","(23.739516666666667,90.37542166666667)","(23.739088333333335,90.37564666666667)","(23.738685,90.37586833333333)","(23.738385,90.37625166666666)","(23.738596666666666,90.37579)","(23.73900666666667,90.37557333333334)","(23.73943166666667,90.37534833333333)","(23.739055,90.375665)","(23.738626666666665,90.3759)","(23.738385,90.37632666666667)","(23.738458333333334,90.37684)","(23.738516666666666,90.377335)","(23.73858,90.37782666666666)","(23.738653333333332,90.37831833333334)","(23.738718333333335,90.37885166666666)","(23.73882,90.37937)","(23.738918333333334,90.37985666666667)","(23.739011666666666,90.38037333333334)","(23.73911,90.38087)","(23.739563333333333,90.38076833333334)","(23.740016666666666,90.380665)","(23.740221666666667,90.38113)","(23.740321666666667,90.38163333333334)","(23.740418333333334,90.38212166666666)","(23.740513333333332,90.382635)","(23.74065,90.38311)","(23.740193333333334,90.383205)","(23.739728333333332,90.383285)","(23.739285,90.38338333333333)","(23.73884,90.38348)","(23.738375,90.38359)","(23.73793,90.38373)","(23.737483333333333,90.38383333333333)","(23.73701833333333,90.38393166666667)","(23.736551666666667,90.384025)","(23.736095,90.384125)","(23.735651666666666,90.38423666666667)","(23.735195,90.384365)","(23.734751666666668,90.38448166666667)","(23.734283333333334,90.38459)","(23.733815,90.384705)","(23.7654683,90.365155)","(23.7646234,90.3654482)","(23.764188,90.3651851)"}	f	0	mahabhu	t	\N
2149	2024-02-03 02:27:26.668403+06	5	morning	{NULL,"(37,\\"2024-02-03 02:36:13.157+06\\")","(38,\\"2024-02-03 02:40:04.731+06\\")","(39,\\"2024-02-03 02:43:11.665+06\\")","(40,\\"2024-02-03 02:47:02.649+06\\")","(70,\\"2024-02-03 20:25:22.583+06\\")"}	to_buet	Ba-35-1461	t	arif43	nazmul	2024-02-03 20:25:49.592864+06	(23.76479,90.365395)	(23.7275567,90.3917012)	{"(23.7645899,90.3654602)","(23.7641791,90.3651597)","(23.7640079,90.364545)","(23.7638432,90.3639419)","(23.763665,90.3633206)","(23.7634948,90.3627313)","(23.7633133,90.3621218)","(23.7631214,90.3614863)","(23.7629498,90.3608901)","(23.7627899,90.3602684)","(23.7626161,90.3596785)","(23.7624275,90.3590591)","(23.7620054,90.3588835)","(23.7615043,90.3589169)","(23.7610044,90.3589301)","(23.7605168,90.3588805)","(23.7599776,90.3589364)","(23.7595058,90.3590893)","(23.7590332,90.3593216)","(23.7585796,90.3595811)","(23.7581502,90.3599098)","(23.7577339,90.3602707)","(23.7573619,90.3606604)","(23.7571057,90.3610809)","(23.7569602,90.3616513)","(23.7564185,90.3623344)","(23.7558515,90.3629871)","(23.7553034,90.3636434)","(23.7547583,90.3643097)","(23.7542302,90.3649617)","(23.7536535,90.3656283)","(23.7531108,90.3662656)","(23.7525503,90.3669249)","(23.7519525,90.3674845)","(23.7512668,90.3679917)","(23.7505766,90.3684601)","(23.7498687,90.36895)","(23.7492048,90.3694127)","(23.7485217,90.3698854)","(23.7478084,90.3703668)","(23.7471318,90.3708218)","(23.7464751,90.3712702)","(23.7458061,90.3717183)","(23.7451382,90.372171)","(23.7444118,90.3726267)","(23.7437168,90.3731001)","(23.743025,90.3735753)","(23.7423222,90.373999)","(23.7415994,90.374366)","(23.7408601,90.3747486)","(23.7401172,90.3751167)","(23.7393483,90.3755133)","(23.738628,90.3758984)","(23.739166,90.3754905)","(23.7396567,90.3752282)","(23.7347051,90.3844951)","(23.7340926,90.3846321)","(23.7334171,90.3848151)","(23.7327804,90.3849898)","(23.7324695,90.385514)","(23.732523,90.3861867)","(23.732625,90.3869148)","(23.7320649,90.3869498)","(23.7315155,90.3869588)","(23.7310033,90.387045)","(23.7305339,90.3871921)","(23.730093,90.387362)","(23.7296017,90.3876288)","(23.7291601,90.3879544)","(23.7287431,90.3883196)","(23.728353,90.388695)","(23.7279634,90.3890946)","(23.7276237,90.3894399)","(23.7276037,90.3903194)","(23.7277651,90.3908467)","(23.7279577,90.3913836)","(23.7275677,90.3917011)","(23.7276,90.3917)"}	f	0	khairul	t	\N
2745	2024-04-16 08:39:18.181484+06	6	afternoon	{"(70,\\"2024-03-04 08:39:21.034+06\\")",NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-12-8888	t	abdulkarim6	nazmul	2024-03-04 08:42:52.96095+06	(23.7262983,90.3917733)	(23.741204,90.3828098)	{"(23.7262557,90.391783)","(23.7274178,90.3917104)","(23.7258306,90.3918294)","(23.7272717,90.38963)","(23.7290064,90.3880841)","(23.7312,90.38701)","(23.7318251,90.3870021)","(23.7324947,90.385617)","(23.7331496,90.3847397)","(23.7349525,90.3843496)","(23.7370241,90.3838982)","(23.7392464,90.3833228)"}	f	0	shamsul54	t	{"2024-03-04 08:41:19.661+06","2024-03-04 08:41:30.143+06","2024-03-04 08:41:40.261+06","2024-03-04 08:41:56.44+06","2024-03-04 08:42:01.063+06","2024-03-04 08:42:11.03+06","2024-03-04 08:42:21.062+06","2024-03-04 08:42:31.058+06","2024-03-04 08:42:41.05+06","2024-03-04 08:42:51.036+06"}
2698	2024-03-04 08:04:07.611337+06	6	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-48-5757	t	monu67	nazmul	2024-03-04 08:04:11.563212+06	(23.75636,90.37533)	(23.7563535,90.3753339)	{"(23.7563535,90.3753339)"}	f	0	zahir53	t	{"2024-03-04 08:04:08.948+06"}
2079	2024-02-06 08:00:16.411533+06	5	evening	{NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:16:47.939+06\\")"}	from_buet	Ba-34-7413	t	ibrahim	nazmul	2024-02-09 10:17:19.010068+06	(23.7728923,90.3607481)	(23.7275682,90.3917004)	{"(23.77291265,90.36078955)","(23.7275696,90.3917003)"}	f	0	mahabhu	t	\N
2472	2024-02-12 02:19:39.100436+06	6	afternoon	{"(41,\\"1970-01-01 06:00:00+06\\")","(42,\\"1970-01-01 06:00:00+06\\")","(43,\\"1970-01-01 06:00:00+06\\")","(44,\\"1970-01-01 06:00:00+06\\")","(45,\\"1970-01-01 06:00:00+06\\")","(46,\\"1970-01-01 06:00:00+06\\")","(47,\\"1970-01-01 06:00:00+06\\")","(48,\\"1970-01-01 06:00:00+06\\")","(49,\\"1970-01-01 06:00:00+06\\")","(70,\\"1970-01-01 06:00:00+06\\")"}	from_buet	Ba-77-7044	t	rafiqul	\N	\N	(23.7626636,90.3702299)	\N	{"(23.7628267,90.3604167)","(23.762655,90.3598217)","(23.7624735,90.359203)","(23.7619199,90.3588915)","(23.7613815,90.3589234)","(23.7608752,90.35893)"}	f	7	siddiq2	t	{}
2281	2024-02-11 20:57:27.569138+06	8	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-69-8288	t	ibrahim	nazmul	2024-02-11 20:59:22.769092+06	(23.831868,90.3532217)	(23.8318658,90.353245)	{"(23.8318665,90.3532303)","(23.8318658,90.353245)"}	f	63	nasir81	t	\N
2722	2024-03-04 08:06:06.849638+06	6	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-03-04 08:06:08.254+06\\")"}	from_buet	Ba-48-5757	t	monu67	nazmul	2024-03-04 08:10:57.239359+06	(23.7273783,90.3917117)	(23.7275962,90.3893521)	{"(23.7273741,90.3917119)","(23.7268087,90.3917)","(23.7263268,90.3917665)","(23.7258569,90.3918431)","(23.7262447,90.3910535)","(23.7265612,90.3905939)","(23.7268696,90.3901736)","(23.7271702,90.3897778)","(23.7275965,90.3893538)"}	f	0	zahir53	t	{"2024-03-04 08:06:08.254+06","2024-03-04 08:06:32.83+06","2024-03-04 08:06:58.234+06","2024-03-04 08:07:18.253+06","2024-03-04 08:07:35.28+06","2024-03-04 08:07:45.302+06","2024-03-04 08:07:55.827+06","2024-03-04 08:08:08.259+06","2024-03-04 08:08:26.842+06"}
2697	2024-03-04 08:43:07.152328+06	6	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-12-8888	t	abdulkarim6	nazmul	2024-03-04 08:43:31.927773+06	(23.74498,90.3818)	(23.7481783,90.3799595)	{"(23.7450123,90.3817901)","(23.7460175,90.3812361)","(23.7481783,90.3799595)"}	f	0	shamsul54	t	{"2024-03-04 08:43:08.54+06","2024-03-04 08:43:18.54+06","2024-03-04 08:43:28.529+06"}
3014	2024-04-21 08:11:39.838833+06	5	morning	{"(36,\\"2024-03-04 08:11:55.159+06\\")",NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-03-04 08:14:33.972923+06	(23.76576,90.36505)	(23.7631504,90.36158)	{"(23.7657523,90.3650529)","(23.7651676,90.3652727)","(23.7647081,90.3654211)","(23.7642095,90.3655639)","(23.7641235,90.3649523)","(23.7639501,90.3643404)","(23.7637818,90.3637069)","(23.7635983,90.3630934)","(23.76344,90.36253)","(23.763246,90.3619023)"}	f	45	rashid56	t	{"2024-03-04 08:11:41.247+06","2024-03-04 08:11:55.16+06","2024-03-04 08:12:05.324+06","2024-03-04 08:12:21.231+06","2024-03-04 08:12:35.83+06","2024-03-04 08:12:56.818+06","2024-03-04 08:13:18.321+06","2024-03-04 08:13:39.829+06","2024-03-04 08:14:00.226+06","2024-03-04 08:14:21.328+06"}
2151	2024-02-15 18:12:58.319479+06	5	evening	{NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-35-1461	t	arif43	nazmul	2024-02-15 18:13:14.293723+06	(23.76584,90.3650183)	(23.7653776,90.3651861)	{"(23.765635,90.3650952)"}	f	0	khairul	t	\N
2620	2024-03-01 21:17:52.040009+06	6	morning	{"(41,\\"2024-02-20 21:18:01.482+06\\")","(42,\\"2024-02-20 21:18:32.665+06\\")","(43,\\"2024-02-20 21:20:28.355+06\\")","(44,\\"2024-02-20 21:20:59.207+06\\")","(45,\\"2024-02-20 21:21:09.166+06\\")","(46,\\"2024-02-20 21:21:38.265+06\\")","(47,\\"2024-02-20 21:22:28.248+06\\")","(48,\\"2024-02-20 21:22:48.29+06\\")","(49,\\"2024-02-20 21:22:58.342+06\\")","(70,\\"2024-02-20 21:26:58.312+06\\")"}	to_buet	Ba-20-3066	t	ibrahim	\N	2024-02-20 21:29:15.78355+06	(23.80698,90.36877)	(23.7274578,90.3917003)	{"(23.8068974,90.3686226)","(23.8069113,90.3680985)","(23.8064376,90.3661024)","(23.8056637,90.36458)","(23.8047383,90.3629538)","(23.8035621,90.3611911)","(23.804919,90.36304)","(23.8060102,90.3649578)","(23.8050266,90.3634844)","(23.8038523,90.3616087)","(23.8026012,90.3597008)","(23.8014093,90.3577803)","(23.8002593,90.3560078)","(23.7989467,90.3539183)","(23.7980325,90.3523112)","(23.7969291,90.3539753)","(23.7949698,90.3529268)","(23.7917286,90.3537862)","(23.7891069,90.3539725)","(23.7864248,90.3540193)","(23.7837587,90.3540872)","(23.7821474,90.3521304)","(23.7798168,90.3529847)","(23.7794433,90.3561006)","(23.7786012,90.3589356)","(23.7782849,90.3613441)","(23.7767219,90.3633209)","(23.77521,90.3654083)","(23.7737951,90.3670122)","(23.7712978,90.3682384)","(23.7689603,90.368969)","(23.7666923,90.369837)","(23.7647705,90.370615)","(23.7623697,90.3717275)","(23.7607046,90.3727393)","(23.75853,90.37406)","(23.75636,90.37533)","(23.7545399,90.3761911)","(23.7522451,90.3777765)","(23.7501361,90.3788746)","(23.7480412,90.3801657)","(23.7460441,90.3813481)","(23.7439957,90.382535)","(23.7414863,90.382953)","(23.7392458,90.3834656)","(23.7369788,90.3838981)","(23.7349283,90.3843835)","(23.7322601,90.3851193)","(23.7320538,90.3864995)","(23.7308831,90.3874204)","(23.7285798,90.3880004)","(23.7268324,90.3902009)","(23.7281109,90.3920881)","(23.7272892,90.3917698)","(23.7261476,90.391722)","(23.7274455,90.3917003)","(23.7263949,90.3917074)"}	f	0	mahabhu	t	\N
2622	2024-03-02 16:13:02.692775+06	6	evening	{"(41,\\"2024-02-21 16:13:28.001+06\\")","(42,\\"2024-02-21 16:14:10.638+06\\")","(43,\\"2024-02-21 16:16:05.131+06\\")","(44,\\"2024-02-21 16:16:37.627+06\\")","(45,\\"2024-02-21 16:16:48.521+06\\")","(46,\\"2024-02-21 16:17:08.755+06\\")","(47,\\"2024-02-21 16:18:01.072+06\\")","(48,\\"2024-02-21 16:19:44.183+06\\")","(49,\\"2024-02-21 16:20:44.174+06\\")","(70,\\"2024-02-21 16:13:04.14+06\\")"}	from_buet	Ba-20-3066	t	ibrahim	\N	2024-02-21 16:30:42.654123+06	(23.7276,90.3917)	(23.748695,90.3797804)	{"(23.7275253,90.3917049)","(23.80715,90.36879)","(23.8068418,90.3677569)","(23.8063046,90.3657565)","(23.8054319,90.3642126)","(23.8044424,90.3624709)","(23.8033591,90.3608882)","(23.803943,90.3615159)","(23.8050778,90.363367)","(23.8059774,90.3651481)","(23.8048699,90.3631855)","(23.8036607,90.3613403)","(23.8024163,90.3594121)","(23.801177,90.3574258)","(23.8000074,90.3556173)","(23.7988523,90.3537763)","(23.79769,90.3539377)","(23.7965205,90.3533939)","(23.7934017,90.3536517)","(23.790803,90.3538361)","(23.78785,90.35395)","(23.7851447,90.3539394)","(23.7825867,90.3523867)","(23.7808352,90.3532731)","(23.77962,90.35566)","(23.7789832,90.3579819)","(23.778621,90.3599277)","(23.7784103,90.3604097)","(23.7781536,90.360903)","(23.7779018,90.3613316)","(23.7776086,90.3618062)","(23.777287,90.3623644)","(23.77698,90.3628258)","(23.7766855,90.3632708)","(23.7763947,90.3636995)","(23.776084,90.3641475)","(23.7757911,90.364557)","(23.7754742,90.3649973)","(23.7751632,90.3654065)","(23.7748117,90.3657841)","(23.7744668,90.3661963)","(23.7741295,90.3665483)","(23.7734007,90.3671561)","(23.7729572,90.367428)","(23.7724937,90.3676132)","(23.772027,90.3677832)","(23.7715753,90.3679548)","(23.7711236,90.3681216)","(23.7706535,90.3682916)","(23.7701918,90.3684732)","(23.7697218,90.3686667)","(23.769273,90.3688436)","(23.7687916,90.3690249)","(23.7683219,90.3692213)","(23.7678417,90.3694066)","(23.7673622,90.3695811)","(23.7669054,90.3697576)","(23.7664622,90.3699289)","(23.7659665,90.3701335)","(23.7654732,90.3703375)","(23.7649743,90.3705328)","(23.7644856,90.3707214)","(23.7640072,90.3709064)","(23.7635702,90.3710998)","(23.7631303,90.3713298)","(23.7626655,90.3715964)","(23.7622353,90.3718415)","(23.76182,90.3720749)","(23.7613457,90.3723414)","(23.7609083,90.3726131)","(23.760498,90.3728623)","(23.7600499,90.3731168)","(23.7596346,90.3733571)","(23.7592031,90.3736274)","(23.75876,90.3739112)","(23.7583418,90.3742094)","(23.7578387,90.3744722)","(23.7573693,90.3747113)","(23.7565923,90.3751934)","(23.7561515,90.3754523)","(23.755691,90.3757276)","(23.7552688,90.3759763)","(23.7548125,90.3762661)","(23.7543673,90.3765428)","(23.7539271,90.3767714)","(23.7534754,90.3770214)","(23.7530286,90.3772631)","(23.7526056,90.3774778)","(23.7521605,90.3777414)","(23.7517185,90.3780049)","(23.7509027,90.3784722)","(23.7504389,90.3787415)","(23.7500253,90.378987)","(23.7495854,90.3792556)","(23.7491608,90.3795108)","(23.7487183,90.3797699)"}	f	0	mahabhu	t	\N
2721	2024-03-04 08:44:05.693108+06	6	afternoon	{"(70,\\"2024-03-04 08:44:07.099+06\\")",NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-12-8888	t	abdulkarim6	nazmul	2024-03-04 08:50:49.455323+06	(23.72694,90.3917067)	(23.7361463,90.3839668)	{"(23.7269358,90.3917065)","(23.7263637,90.3917616)","(23.7259011,90.3918462)","(23.7262447,90.3910535)","(23.7265612,90.3905939)","(23.7268696,90.3901736)","(23.7271703,90.3897775)","(23.727822,90.3891281)","(23.7281999,90.3887798)","(23.7286567,90.3884114)","(23.7290632,90.3880441)","(23.7294271,90.3877499)","(23.7298658,90.3874886)","(23.7303616,90.3872746)","(23.7307969,90.3871214)","(23.7313204,90.3869977)","(23.7321332,90.3869131)","(23.7324868,90.3865323)","(23.7323901,90.3858087)","(23.732295,90.3851118)","(23.7329665,90.38481)","(23.7336698,90.3846033)","(23.7341886,90.3844661)","(23.7347343,90.3843536)","(23.7352435,90.3842303)","(23.7358063,90.384065)"}	f	0	shamsul54	t	{"2024-03-04 08:47:50.75+06","2024-03-04 08:48:12.116+06","2024-03-04 08:48:33.129+06","2024-03-04 08:48:54.498+06","2024-03-04 08:49:15.613+06","2024-03-04 08:49:36.12+06","2024-03-04 08:49:57.12+06","2024-03-04 08:50:07.643+06","2024-03-04 08:50:27.122+06","2024-03-04 08:50:38.617+06"}
2137	2024-02-08 11:02:05.674961+06	8	morning	{NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-09 10:15:09.947+06\\")"}	to_buet	Ba-36-1921	t	rafiqul	nazmul	2024-02-09 20:17:17.085045+06	(23.7525217,90.3538429)	(23.7626577,90.3701649)	{"(23.75248784,90.35385556)","(23.76002136,90.36689164)","(23.76009567,90.36738587)","(23.76066827,90.36762518)","(23.76107535,90.36735947)","(23.76163621,90.36740939)","(23.76223549,90.36685081)","(23.76248042,90.36747988)","(23.76266301,90.36805049)","(23.76284516,90.36868806)","(23.76323172,90.36910766)","(23.76317162,90.36999637)","(23.76282085,90.37031665)","(23.7276,90.3917)"}	f	0	rashid56	t	\N
2871	2024-04-20 23:30:04.581767+06	5	morning	{"(36,\\"2024-03-09 12:30:00+06\\")","(37,\\"2024-03-09 12:33:00+06\\")","(38,\\"2024-03-09 12:40:00+06\\")","(39,\\"2024-03-09 12:45:00+06\\")","(40,\\"2024-03-09 12:50:00+06\\")","(70,\\"2024-03-09 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-03-04 00:09:06.415568+06	(23.7276,90.3917)	(23.7386275,90.3757689)	{"(23.7386126,90.3757794)"}	f	31	azim990	t	{"2024-03-04 00:08:30.72+06"}
3666	2024-04-23 13:13:15.343873+06	5	morning	{"(36,\\"2024-04-23 13:13:27.128+06\\")",NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-23 13:14:38.286211+06	(37.4219983,-122.084)	(23.7638866,90.3641098)	{"(37.4219983,-122.084)","(37.4219983,-122.084)","(23.7651277,90.3652768)","(23.7645126,90.365483)","(23.7641687,90.3651217)","(23.7640046,90.3645362)"}	f	0	rashid56	t	{"2024-04-23 13:13:15.343+06","2024-04-23 13:13:17.269+06","2024-04-23 13:13:27.13+06","2024-04-23 13:13:41.386+06","2024-04-23 13:14:01.686+06","2024-04-23 13:14:22.544+06"}
2138	2024-02-11 21:31:17.768115+06	8	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-11 21:32:35.73+06\\")"}	from_buet	Ba-36-1921	t	rafiqul	nazmul	2024-02-11 21:33:31.247546+06	(23.7276,90.3917)	(23.7275207,90.3917006)	{"(23.7276,90.3917)"}	f	28	rashid56	t	\N
3690	2024-04-23 13:15:12.244724+06	5	morning	{"(36,\\"2024-04-23 13:15:53.901+06\\")",NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-23 13:22:09.446275+06	(23.76645,90.36474)	(23.7593056,90.3591841)	{"(23.76645,90.36474)","(23.766432,90.3647673)","(23.7658975,90.3649994)","(23.7654117,90.3651662)","(23.7649818,90.3653254)","(23.764281,90.3655193)","(23.7641051,90.3648904)","(23.7639301,90.3642685)","(23.76378,90.3637)","(23.7635883,90.3630601)","(23.76342,90.3624699)","(23.7632346,90.3618747)","(23.7630595,90.3612777)","(23.7628945,90.3606772)","(23.7627263,90.3600537)","(23.7625509,90.3594429)","(23.7623451,90.3588843)","(23.7618191,90.3588982)","(23.7613037,90.3589283)","(23.7608203,90.3589217)","(23.7603135,90.3588949)","(23.7597719,90.358985)","(23.7593218,90.3591766)"}	f	0	rashid56	t	{"2024-04-23 13:18:54.207+06","2024-04-23 13:19:15.608+06","2024-04-23 13:19:36.609+06","2024-04-23 13:19:58.032+06","2024-04-23 13:20:18.34+06","2024-04-23 13:20:39.094+06","2024-04-23 13:20:59.813+06","2024-04-23 13:21:20.144+06","2024-04-23 13:21:41.543+06","2024-04-23 13:22:01.974+06"}
3714	2024-04-23 13:33:31.057793+06	5	morning	{"(36,\\"2024-04-26 12:30:00+06\\")","(37,\\"2024-04-26 12:33:00+06\\")","(38,\\"2024-04-26 12:40:00+06\\")","(39,\\"2024-04-26 12:45:00+06\\")","(40,\\"2024-04-26 12:50:00+06\\")","(70,\\"2024-04-26 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-23 14:02:00.404793+06	(23.7656433,90.3650917)	(23.72658,90.3881981)	{"(23.726622,90.3881592)","(23.7265053,90.3881692)","(23.7266149,90.3881294)"}	f	1	rashid56	t	{"2024-04-23 13:40:51.276+06","2024-04-23 13:43:51.403+06","2024-04-23 13:50:11.337+06"}
2150	2024-02-03 20:29:40.596129+06	5	afternoon	{"(36,\\"2024-02-03 20:31:47.413+06\\")","(37,\\"2024-02-03 20:36:33.414+06\\")","(38,\\"2024-02-03 20:38:29.933+06\\")","(39,\\"2024-02-03 20:40:06.871+06\\")","(40,\\"2024-02-03 20:42:29.778+06\\")","(70,\\"2024-02-03 20:48:23.916+06\\")"}	from_buet	Ba-35-1461	t	arif43	nazmul	2024-02-03 20:51:18.151106+06	(23.7276,90.3917)	(23.7275171,90.3917008)	{"(23.7275747,90.3917011)","(23.766265,90.3648667)","(23.7653851,90.3651851)","(23.7645435,90.3654723)","(23.764162,90.3650983)","(23.7639921,90.3644893)","(23.7638266,90.3638835)","(23.7636499,90.3632703)","(23.7634781,90.3626715)","(23.7632967,90.3620633)","(23.763113,90.3614564)","(23.7629495,90.3608871)","(23.7627899,90.3602685)","(23.7626358,90.3597588)","(23.7624293,90.3590651)","(23.7620049,90.3588648)","(23.7614827,90.3589146)","(23.7609545,90.3589303)","(23.7604214,90.3588882)","(23.7599205,90.3589457)","(23.7594375,90.3591195)","(23.7589666,90.3593559)","(23.7585076,90.359628)","(23.7581063,90.3599415)","(23.7576973,90.360317)","(23.7573422,90.36068)","(23.7571077,90.3611113)","(23.7568605,90.3617724)","(23.7563149,90.3624542)","(23.7557489,90.3631119)","(23.7551732,90.3638001)","(23.75463,90.3644681)","(23.7540965,90.3651171)","(23.7535201,90.3657836)","(23.7529798,90.3664235)","(23.7524969,90.3669887)","(23.7518578,90.367555)","(23.7512315,90.3680154)","(23.7505143,90.3685057)","(23.749866,90.3689514)","(23.7491107,90.3694788)","(23.7483898,90.3699754)","(23.747758,90.3704012)","(23.7470354,90.3708873)","(23.7461948,90.3714551)","(23.7454782,90.37194)","(23.7447866,90.3723902)","(23.7441134,90.372833)","(23.7434961,90.3732527)","(23.742834,90.3737029)","(23.7420746,90.3741136)","(23.7413868,90.3744852)","(23.740686,90.3748359)","(23.7399068,90.3752174)","(23.739209,90.37559)","(23.7385392,90.3759518)","(23.7392136,90.3754628)","(23.7396799,90.3752165)","(23.7389036,90.3757474)","(23.7383907,90.376367)","(23.7385048,90.3772786)","(23.7386295,90.3781382)","(23.7387731,90.3791268)","(23.7389416,90.3799975)","(23.7392385,90.3808448)","(23.7398785,90.3807057)","(23.7402374,90.381087)","(23.7403772,90.3818926)","(23.7405286,90.3827104)","(23.7403405,90.3831992)","(23.7397019,90.3832955)","(23.7391391,90.3834101)","(23.7384989,90.38355)","(23.7378657,90.3837428)","(23.7371249,90.3839101)","(23.7364654,90.3840421)","(23.7358493,90.3841865)","(23.735284,90.3843401)","(23.7346174,90.3845196)","(23.7339702,90.3846673)","(23.7333256,90.3848416)","(23.7327381,90.3850608)","(23.7324829,90.3856161)","(23.7325387,90.3863172)","(23.7326587,90.3869923)","(23.7318661,90.3871311)","(23.7307978,90.387114)","(23.7298859,90.3874568)","(23.72898,90.3881053)","(23.7282289,90.3888284)","(23.72748,90.389658)","(23.7277971,90.390943)","(23.727827,90.3916868)"}	f	2	khairul	t	\N
2077	2024-02-04 14:33:26.147705+06	5	morning	{NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-34-7413	t	ibrahim	nazmul	2024-02-04 15:41:59.714432+06	(23.7267047,90.3882934)	(23.7738773,90.3607218)	{"(23.72670142,90.38834294)","(23.72662115,90.38934122)","(23.72706564,90.38846667)","(23.72701156,90.38740833)","(23.72692634,90.38636139)","(23.72789826,90.38605294)","(23.72883413,90.38580855)","(23.729761,90.38576675)","(23.73074099,90.38571427)","(23.73159195,90.38527448)","(23.73282386,90.38448791)","(23.73372323,90.38484045)","(23.7346514,90.38446164)","(23.73569549,90.38407087)","(23.73685971,90.38382624)","(23.73789558,90.38391045)","(23.73889876,90.3835447)","(23.7399763,90.383203)","(23.74124132,90.38282518)","(23.74251187,90.38251853)","(23.74354504,90.38240553)","(23.74449667,90.38205572)","(23.74547177,90.38182319)","(23.74655476,90.38107447)","(23.7474218,90.38075053)","(23.74912816,90.3792149)","(23.75048469,90.37877427)","(23.75142447,90.37800705)","(23.75242425,90.37745536)","(23.75365548,90.37673968)","(23.75555865,90.37574798)","(23.75713535,90.37464479)","(23.75807558,90.37421568)","(23.75961408,90.37324526)","(23.76063318,90.37273955)","(23.76139989,90.37216997)","(23.76218901,90.3716932)","(23.76351869,90.37098501)","(23.764777,90.37049157)","(23.7656762,90.36990339)","(23.76704277,90.36948851)","(23.76806456,90.36922452)","(23.76936847,90.36843412)","(23.77037556,90.36823122)","(23.77127927,90.36776257)","(23.77246578,90.36716057)","(23.77339877,90.36723635)","(23.77392645,90.36622396)","(23.77409134,90.36524519)","(23.77467,90.36447327)","(23.77440115,90.3633982)","(23.77409111,90.36231585)","(23.77359141,90.36138951)"}	f	0	mahabhu	t	\N
2078	2024-02-04 13:40:42.447506+06	5	afternoon	{NULL,"(37,\\"2024-02-04 14:13:49.626+06\\")","(38,\\"2024-02-04 14:09:40.63+06\\")","(39,\\"2024-02-04 14:06:04.644+06\\")","(40,\\"2024-02-04 14:04:13.311+06\\")","(70,\\"2024-02-04 13:42:07.613+06\\")"}	from_buet	Ba-34-7413	t	ibrahim	nazmul	2024-02-04 14:17:08.831197+06	(23.7277025,90.391553)	(23.758565,90.364045)	{"(23.7277005,90.3915536)","(23.7272151,90.3917681)","(23.7267545,90.3918323)","(23.7262922,90.3919235)","(23.7261866,90.3914254)","(23.726548,90.3908094)","(23.7270001,90.3901624)","(23.7272766,90.3897504)","(23.727589,90.3893203)","(23.7281956,90.3888225)","(23.7285256,90.3884753)","(23.7288433,90.3881179)","(23.7292273,90.3878095)","(23.7323337,90.3854034)","(23.732539,90.3849662)","(23.7329863,90.3848359)","(23.7334396,90.3847276)","(23.7338888,90.384657)","(23.7343437,90.3845413)","(23.7347989,90.3843992)","(23.7352286,90.3842399)","(23.735816,90.384099)","(23.7362957,90.3839276)","(23.7368577,90.3838719)","(23.7375922,90.3837157)","(23.738055,90.3836674)","(23.7385034,90.3835617)","(23.7389441,90.3833578)","(23.7393894,90.3832737)","(23.7394432,90.3827815)","(23.7393307,90.3823006)","(23.739173,90.3814846)","(23.7390219,90.3806199)","(23.7388026,90.3796488)","(23.7386602,90.3788551)","(23.738571,90.3783634)","(23.7384856,90.3778672)","(23.7383949,90.3773851)","(23.7383121,90.3768871)","(23.7382914,90.3763953)","(23.7385267,90.3759654)","(23.7389219,90.3756781)","(23.7393427,90.3754623)","(23.7397452,90.3751643)","(23.7402104,90.3750361)","(23.7408624,90.3747133)","(23.7413335,90.3744239)","(23.7420379,90.3740933)","(23.7425203,90.3737572)","(23.7431309,90.373406)","(23.7436047,90.3730969)","(23.7441206,90.3727575)","(23.7446899,90.3723246)","(23.7450767,90.372024)","(23.7454949,90.3717077)","(23.7459099,90.3714097)","(23.7463337,90.3711167)","(23.7467796,90.3708159)","(23.7471771,90.3705583)","(23.7475997,90.3702801)","(23.7480531,90.370003)","(23.7484648,90.3697361)","(23.7488765,90.3695191)","(23.74927,90.3692409)","(23.7498073,90.3689208)","(23.7502894,90.3685247)","(23.7507021,90.3682338)","(23.7511345,90.3679947)","(23.7514487,90.3676382)","(23.7518593,90.3673785)","(23.7523424,90.3670369)","(23.7527357,90.3667451)","(23.7530168,90.3663358)","(23.7534395,90.3658951)","(23.7537416,90.3655136)","(23.7540984,90.3651801)","(23.7544818,90.3646903)","(23.755042,90.3642056)","(23.7554833,90.3643758)","(23.7560664,90.3642333)","(23.7566818,90.3640182)","(23.7572545,90.3638196)","(23.7578518,90.3635931)","(23.7583087,90.3635162)","(23.7584806,90.3639753)"}	f	1	mahabhu	t	\N
2107	2024-02-04 18:19:32.381476+06	7	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-46-1334	t	altaf	nazmul	2024-02-04 18:20:08.40847+06	(23.8318623,90.3532059)	(23.8318692,90.35325)	{"(23.8318551,90.3532057)","(23.8318692,90.35325)"}	f	0	ASADUZZAMAN	t	\N
2109	2024-02-05 22:51:30.092852+06	7	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-46-1334	t	altaf	nazmul	2024-02-05 23:09:28.494899+06	(23.8318706,90.3532144)	(23.8318746,90.3532107)	{"(23.831872,90.3532168)","(23.8318757,90.3532133)","(23.8318695,90.3532137)","(23.8318628,90.3532185)","(23.831881,90.3532168)"}	f	0	ASADUZZAMAN	t	\N
2131	2024-02-05 23:19:23.516182+06	7	morning	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	to_buet	BA-01-2345	t	altaf	nazmul	2024-02-06 00:36:59.129703+06	(23.8318698,90.3532269)	(23.8318708,90.3532148)	{"(23.8318731,90.3532112)","(23.8318648,90.3532136)","(23.8301727,90.3524148)","(23.8318707,90.3532272)","(23.8318658,90.3532259)","(23.8318582,90.3532063)","(23.8318689,90.3532213)","(23.831863,90.3532112)","(23.8318639,90.3532362)","(23.8318668,90.3532187)","(23.8318724,90.3532007)","(23.8318687,90.3532153)","(23.8318872,90.3532129)","(23.8318773,90.3532055)","(23.8318516,90.3532023)","(23.8318531,90.3532093)","(23.8318705,90.3532156)"}	f	22	jamal7898	t	\N
2132	2024-02-06 10:19:35.659477+06	7	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	BA-01-2345	t	altaf	nazmul	2024-02-06 10:30:30.281269+06	(23.7266902,90.3879919)	(23.7266817,90.3880168)	{"(23.72667916,90.38799154)"}	f	0	jamal7898	t	\N
2108	2024-02-05 20:40:48.094045+06	7	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-46-1334	t	altaf	nazmul	2024-02-05 20:41:41.537487+06	(23.8318808,90.3532134)	(23.8318667,90.3532209)	{"(23.8318711,90.3532043)"}	f	1	ASADUZZAMAN	t	\N
2162	2024-02-06 10:30:36.791862+06	8	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL,"(70,\\"2024-02-06 11:05:20.955+06\\")"}	from_buet	Ba-12-8888	t	altaf	nazmul	2024-02-06 11:19:48.992364+06	(23.7266776,90.3879838)	(23.7260613,90.3911528)	{"(23.72667978,90.38800051)","(23.72655213,90.3890882)","(23.72599893,90.38989607)","(23.72630644,90.39083014)"}	f	0	sharif86r	t	\N
2317	2024-02-15 18:20:36.361472+06	5	morning	{"(36,\\"2024-02-15 18:20:41.32+06\\")",NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-93-6087	t	nazrul6	nazmul	2024-02-15 18:21:53.360111+06	(23.765385,90.365185)	(23.7653669,90.3651875)	{"(23.7653684,90.3651884)"}	f	0	alamgir	t	\N
2163	2024-02-07 15:21:48.683591+06	8	evening	{NULL,NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-12-8888	t	altaf	nazmul	2024-02-07 15:22:04.064928+06	(23.7626808,90.3702093)	(23.7626784,90.3702063)	{}	f	0	sharif86r	t	\N
2165	2024-02-07 15:41:39.037957+06	2	afternoon	{NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-17-3886	t	altaf	nazmul	2024-02-07 15:56:48.541973+06	(23.762673,90.3702144)	(23.7626853,90.3702127)	{"(23.7626798,90.3702076)","(23.7626805,90.3702177)","(23.7626843,90.3702124)","(23.7626798,90.3702068)","(23.7626741,90.3702058)"}	f	0	siddiq2	t	\N
2166	2024-02-07 16:03:05.438002+06	2	evening	{NULL,NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-17-3886	t	altaf	nazmul	2024-02-07 16:05:05.079601+06	(23.7626788,90.3702223)	(23.7626733,90.3702137)	{"(23.7626788,90.3702108)","(23.7626792,90.3702216)"}	f	0	siddiq2	t	\N
2768	2024-04-18 03:41:16.341113+06	6	morning	{"(41,\\"2024-03-04 03:41:22.135+06\\")","(42,\\"2024-03-04 03:43:02.138+06\\")","(43,\\"2024-03-04 03:45:28.461+06\\")","(44,\\"2024-03-04 03:45:49.208+06\\")","(45,\\"2024-03-04 03:45:59.679+06\\")","(46,\\"2024-03-04 03:46:30.073+06\\")","(47,\\"2024-03-04 03:49:32.183+06\\")","(48,\\"2024-03-04 03:51:12.2+06\\")","(49,\\"2024-03-04 03:52:14.354+06\\")",NULL}	to_buet	Ba-97-6734	t	shahid88	nazmul	2024-03-04 03:59:09.086694+06	(23.8069,90.3684196)	(23.7565917,90.3751795)	{"(23.8068919,90.3679729)","(23.8067434,90.3672336)","(23.8065701,90.3664902)","(23.8063069,90.3657702)","(23.8059599,90.3651182)","(23.8057012,90.3646451)","(23.8053615,90.3640898)","(23.8051214,90.3636551)","(23.8048842,90.3631582)","(23.8039342,90.3617048)","(23.8034199,90.36069)","(23.8044705,90.3623466)","(23.8055686,90.3642399)","(23.8044216,90.3624427)","(23.8030847,90.360437)","(23.8020232,90.3587899)","(23.8007631,90.3567949)","(23.7995332,90.3548451)","(23.7982931,90.3539243)","(23.7975221,90.3535512)","(23.7952826,90.353468)","(23.7924633,90.3537267)","(23.7898367,90.3539)","(23.78716,90.35397)","(23.78448,90.35356)","(23.78209,90.35213)","(23.7813789,90.3522862)","(23.7811185,90.352753)","(23.7808535,90.3532298)","(23.7805918,90.3537267)","(23.7803168,90.3542847)","(23.78008,90.3547984)","(23.7798467,90.3552564)","(23.7795957,90.3557388)","(23.7793376,90.3562025)","(23.7791736,90.356736)","(23.7790907,90.3572563)","(23.7790221,90.3577676)","(23.7789417,90.3583014)","(23.778874,90.3588328)","(23.7787857,90.3593529)","(23.7786557,90.3598588)","(23.7782357,90.3607391)","(23.7779705,90.3612077)","(23.7777137,90.3616327)","(23.7774571,90.36207)","(23.7771587,90.3625407)","(23.7768787,90.3629603)","(23.776607,90.3633769)","(23.7763127,90.363807)","(23.7760004,90.364254)","(23.7757071,90.364664)","(23.7754241,90.365054)","(23.7750771,90.3655063)","(23.7747524,90.3658581)","(23.7743979,90.3662712)","(23.7739864,90.3666868)","(23.7735676,90.3670295)","(23.7731713,90.3673091)","(23.7726749,90.3675443)","(23.7722091,90.3677179)","(23.7717106,90.367898)","(23.7712588,90.3680714)","(23.7707863,90.3682373)","(23.7702876,90.3684319)","(23.7698269,90.3686217)","(23.7693636,90.3688098)","(23.7689135,90.3689782)","(23.7684451,90.3691698)","(23.7679685,90.3693617)","(23.767493,90.3695352)","(23.7670018,90.36972)","(23.766533,90.3699033)","(23.7660588,90.3700957)","(23.7655628,90.3703003)","(23.7651109,90.370482)","(23.7646214,90.3706693)","(23.764141,90.3708494)","(23.763654,90.3710627)","(23.7631822,90.3713013)","(23.7627504,90.3715479)","(23.7623204,90.3717947)","(23.7619052,90.3720265)","(23.7614305,90.3722947)","(23.7609903,90.3725614)","(23.7605402,90.3728366)","(23.7600932,90.3730934)","(23.759678,90.3733321)","(23.7592449,90.3736007)","(23.7588017,90.3738845)","(23.7583802,90.3741794)","(23.7578824,90.3744529)","(23.7574035,90.3746827)","(23.7569902,90.3749398)","(23.7565917,90.3751795)"}	f	0	abdulbari4	t	{"2024-03-04 03:57:27.795+06","2024-03-04 03:57:32.147+06","2024-03-04 03:57:42.676+06","2024-03-04 03:57:53.163+06","2024-03-04 03:58:03.677+06","2024-03-04 03:58:14.17+06","2024-03-04 03:58:32.285+06","2024-03-04 03:58:42.29+06","2024-03-04 03:58:52.289+06","2024-03-04 03:59:02.292+06"}
2746	2024-04-17 08:16:56.35776+06	6	evening	{}	from_buet	Ba-48-5757	t	monu67	nazmul	2024-03-04 08:35:13.012338+06	(23.7269183,90.391705)	(23.7675519,90.369385)	{"(23.7269011,90.3917044)","(23.7263424,90.3917649)","(23.7258703,90.3918399)","(23.7260572,90.3913731)","(23.7263313,90.3909287)","(23.7266198,90.3905097)","(23.7269487,90.3900634)","(23.7272577,90.3896484)","(23.7278699,90.38908)","(23.7282612,90.388783)","(23.7286712,90.3883868)","(23.7290543,90.388045)","(23.7294735,90.3877088)","(23.7299291,90.387441)","(23.7304143,90.3872379)","(23.7308612,90.3870859)","(23.7313853,90.3869721)","(23.7319051,90.3869003)","(23.7324332,90.3869419)","(23.7324601,90.3863619)","(23.7323717,90.3856719)","(23.7323848,90.3850018)","(23.7330681,90.38478)","(23.7335447,90.3846497)","(23.7341467,90.3844736)","(23.7346333,90.3843912)","(23.7352281,90.3842265)","(23.7356994,90.384104)","(23.7363084,90.3839307)","(23.7371999,90.3837322)","(23.7376877,90.3836169)","(23.7381995,90.3834903)","(23.7387476,90.3833736)","(23.7392481,90.3832784)","(23.7397762,90.3831635)","(23.7403064,90.3830419)","(23.7408247,90.3829151)","(23.741318,90.3827851)","(23.741818,90.3826601)","(23.7423001,90.3825401)","(23.7428444,90.3824084)","(23.7433366,90.3822816)","(23.7438565,90.3821499)","(23.7443383,90.3820331)","(23.7447974,90.3818945)","(23.7453219,90.3816028)","(23.7458182,90.3813263)","(23.7462668,90.3810632)","(23.7467397,90.380784)","(23.7471767,90.3805278)","(23.7476318,90.3802544)","(23.7481182,90.3799712)","(23.7485688,90.3797008)","(23.7490373,90.3794075)","(23.7495276,90.3791255)","(23.7499697,90.3788703)","(23.7509248,90.3783252)","(23.7514445,90.3780121)","(23.7519066,90.3777499)","(23.7523605,90.3774902)","(23.7528016,90.3772092)","(23.7532957,90.3769523)","(23.7537255,90.3767167)","(23.7542636,90.3764776)","(23.7546802,90.3761846)","(23.7551702,90.3758831)","(23.7556421,90.3755937)","(23.7560979,90.3753181)","(23.7565969,90.3750259)","(23.7570623,90.3747524)","(23.7574978,90.374517)","(23.7579891,90.3742107)","(23.7584527,90.3739138)","(23.7588927,90.3736487)","(23.7593312,90.3733887)","(23.7597928,90.3731204)","(23.7602198,90.3728702)","(23.7607128,90.3725737)","(23.7611665,90.3723052)","(23.76158,90.37207)","(23.7620778,90.3717886)","(23.7625397,90.3715301)","(23.7630198,90.37126)","(23.7634902,90.3710011)","(23.7639653,90.3708023)","(23.7644663,90.3705929)","(23.7649487,90.370389)","(23.7654638,90.3701729)","(23.7659901,90.3699632)","(23.766474,90.3697747)","(23.7669647,90.3695878)","(23.7674552,90.3694057)"}	f	0	zahir53	t	{"2024-03-04 08:33:34.746+06","2024-03-04 08:33:39.491+06","2024-03-04 08:33:49.646+06","2024-03-04 08:34:00.123+06","2024-03-04 08:34:10.214+06","2024-03-04 08:34:21.191+06","2024-03-04 08:34:32.12+06","2024-03-04 08:34:42.244+06","2024-03-04 08:34:52.637+06","2024-03-04 08:35:03.148+06"}
3643	2024-04-23 00:17:15.198481+06	5	afternoon	{"(70,\\"2024-04-23 00:17:17.393+06\\")","(40,\\"2024-04-23 00:24:50.483+06\\")","(39,\\"2024-04-23 00:25:48.205+06\\")","(38,\\"2024-04-23 00:27:14.637+06\\")","(37,\\"2024-04-23 00:29:06.993+06\\")","(36,\\"2024-04-23 00:37:03.729+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	2024-04-23 00:44:05.92217+06	(23.726855,90.3917017)	(23.7670727,90.3639272)	{"(23.726855,90.3917017)","(23.726855,90.3917017)","(23.7263883,90.3917583)","(23.7259383,90.3918467)","(23.72606,90.39137)","(23.7263333,90.390925)","(23.72663,90.3904983)","(23.7269333,90.3900867)","(23.727245,90.38967)","(23.7275967,90.3893517)","(23.7279417,90.38901)","(23.728315,90.3887333)","(23.7286867,90.3883717)","(23.7290467,90.38805)","(23.7294167,90.3877467)","(23.7298417,90.3874833)","(23.7302817,90.3872867)","(23.7307267,90.387125)","(23.73118,90.3870133)","(23.73164,90.38694)","(23.732135,90.3869133)","(23.7325,90.3866233)","(23.732435,90.3861167)","(23.7323617,90.38561)","(23.732295,90.3851117)","(23.732705,90.3848883)","(23.7331717,90.3847483)","(23.7336283,90.384615)","(23.7340967,90.3844833)","(23.7345733,90.384395)","(23.7350233,90.3842783)","(23.7354683,90.38416)","(23.735935,90.3840283)","(23.7364783,90.383895)","(23.73785,90.38358)","(23.73949,90.38323)","(23.73922,90.38184)","(23.73888,90.38011)","(23.7385483,90.3782517)","(23.7383233,90.3765033)","(23.73917,90.37549)","(23.7406917,90.3746883)","(23.7413067,90.3743683)","(23.742115,90.373965)","(23.74275,90.37362)","(23.7434983,90.3731117)","(23.744165,90.3726683)","(23.7448033,90.37221)","(23.7454867,90.3717633)","(23.74609,90.3713617)","(23.7467833,90.370895)","(23.7474417,90.37046)","(23.7481067,90.3700067)","(23.74877,90.36954)","(23.7494217,90.3690983)","(23.7500383,90.3686833)","(23.75069,90.3682367)","(23.75132,90.36781)","(23.751935,90.3673683)","(23.7524983,90.3668633)","(23.75295,90.3663333)","(23.7534817,90.3657167)","(23.7540767,90.3650267)","(23.7545867,90.3644117)","(23.755055,90.3638433)","(23.7555617,90.3632467)","(23.75605,90.36267)","(23.756555,90.3620617)","(23.75698,90.36144)","(23.75704,90.36089)","(23.756925,90.360395)","(23.7567883,90.359895)","(23.75661,90.3594017)","(23.75649,90.3589067)","(23.7567183,90.35935)","(23.75689,90.3598117)","(23.7570083,90.3602883)","(23.7571,90.360775)","(23.7570783,90.3612717)","(23.7571967,90.3617467)","(23.7630467,90.3644233)","(23.7634862,90.3642652)","(23.7639405,90.3643023)","(23.7640741,90.3647857)","(23.7645365,90.3646889)","(23.7649788,90.3645303)","(23.7654125,90.3643717)","(23.7658463,90.3642138)","(23.7663272,90.3640529)","(23.7667837,90.3639011)","(23.7670727,90.3639273)"}	f	0	mahbub777	t	{"2024-04-23 00:37:22.508+06","2024-04-23 00:37:46.807+06","2024-04-23 00:38:04.047+06","2024-04-23 00:38:19.946+06","2024-04-23 00:38:34.637+06","2024-04-23 00:38:48.64+06","2024-04-23 00:39:04.536+06","2024-04-23 00:39:25.532+06","2024-04-23 00:39:45.412+06","2024-04-23 00:40:46.297+06"}
3667	2024-04-23 00:44:59.637942+06	5	afternoon	{"(70,\\"2024-04-24 20:10:00+06\\")","(40,\\"2024-04-24 20:07:00+06\\")","(39,\\"2024-04-24 20:00:00+06\\")","(38,\\"2024-04-24 19:55:00+06\\")","(37,\\"2024-04-24 19:50:00+06\\")","(36,\\"2024-04-24 19:40:00+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	2024-04-26 14:45:45.157783+06	(23.7267494,90.3917021)	(23.7380187,90.3836977)	{"(23.738045,90.3836933)"}	f	1	mahbub777	t	{"2024-04-26 14:45:39.087+06"}
3858	2024-04-25 14:23:10.117609+06	5	morning	{"(36,\\"2024-04-25 14:23:25.586+06\\")","(37,\\"2024-04-25 14:31:21.57+06\\")","(38,\\"2024-04-25 14:35:08.73+06\\")","(39,\\"2024-04-25 14:38:19.563+06\\")","(40,\\"2024-04-25 14:40:56.104+06\\")",NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-25 14:49:58.592245+06	(23.7654683,90.365155)	(23.7359042,90.3841727)	{"(23.7654683,90.365155)","(23.7654457,90.3651634)","(23.7648319,90.3653824)","(23.7643781,90.3655219)","(23.764139,90.3650108)","(23.7639583,90.3643684)","(23.7637883,90.3637351)","(23.7634423,90.3625655)","(23.7632725,90.3619877)","(23.7631089,90.3614377)","(23.7629278,90.3608215)","(23.7627808,90.3602352)","(23.7626184,90.3596851)","(23.7624652,90.3591748)","(23.7620549,90.3588683)","(23.7615827,90.3589136)","(23.7611015,90.3589304)","(23.7606015,90.3588905)","(23.7601182,90.3589114)","(23.7596386,90.3590109)","(23.7591734,90.3592478)","(23.7587292,90.3594835)","(23.7583178,90.3597614)","(23.7579152,90.3600942)","(23.75756,90.3604636)","(23.7571873,90.3608186)","(23.7570669,90.3613231)","(23.75676,90.3619108)","(23.7562332,90.3625455)","(23.7556964,90.3631733)","(23.755151,90.3638305)","(23.7546527,90.3644408)","(23.7543235,90.3648515)","(23.7538675,90.365384)","(23.7534669,90.365845)","(23.7531051,90.3662708)","(23.7526571,90.3668017)","(23.7522814,90.3672396)","(23.751707,90.3676717)","(23.7513125,90.3679544)","(23.7506433,90.3684151)","(23.750005,90.3688567)","(23.7495738,90.3691549)","(23.7490192,90.369554)","(23.7485869,90.3698401)","(23.7480334,90.3702166)","(23.7475284,90.370555)","(23.7470438,90.3708821)","(23.7464752,90.37127)","(23.7460559,90.371546)","(23.7454451,90.3719632)","(23.7447537,90.37241)","(23.7440471,90.3728781)","(23.7433903,90.3733199)","(23.7427569,90.3737563)","(23.7423223,90.3739988)","(23.7417082,90.3742811)","(23.7412489,90.3745551)","(23.7406597,90.3748487)","(23.7401172,90.3751166)","(23.7396016,90.3753749)","(23.7389851,90.375702)","(23.7385722,90.3759303)","(23.7391672,90.3754898)","(23.7396152,90.3752504)","(23.7392619,90.3755643)","(23.7387369,90.3758363)","(23.7383876,90.3763674)","(23.7384607,90.3768712)","(23.7385438,90.3775432)","(23.7386467,90.3782697)","(23.7387006,90.3787605)","(23.7387994,90.3792651)","(23.7389094,90.3798094)","(23.739073,90.3806886)","(23.7396275,90.3807568)","(23.7402919,90.3806005)","(23.740247,90.38116)","(23.7403827,90.3819223)","(23.7404718,90.3824048)","(23.7405933,90.3830575)","(23.7401019,90.3832331)","(23.7394671,90.3833495)","(23.738864,90.3834794)","(23.7383505,90.3835993)","(23.7379157,90.3837334)","(23.7374034,90.3838517)","(23.7367453,90.3839868)","(23.7360966,90.3841249)"}	f	0	rashid56	t	{"2024-04-25 14:47:03.584+06","2024-04-25 14:47:21.673+06","2024-04-25 14:47:41.69+06","2024-04-25 14:48:01.689+06","2024-04-25 14:48:21.66+06","2024-04-25 14:48:36.584+06","2024-04-25 14:48:51.693+06","2024-04-25 14:49:07.615+06","2024-04-25 14:49:28.589+06","2024-04-25 14:49:49.611+06"}
3908	2024-04-25 14:58:57.886872+06	5	morning	{"(36,\\"2024-04-25 14:59:29.27+06\\")","(37,\\"2024-04-25 15:07:19.315+06\\")",NULL,NULL,NULL,NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-25 15:11:03.494436+06	(23.76613,90.36491)	(23.7521677,90.3673378)	{"(23.76613,90.36491)","(23.7661087,90.3649184)","(23.7655135,90.3651395)","(23.7648761,90.3653696)","(23.7644191,90.3655175)","(23.7641522,90.3650595)","(23.7639878,90.3644756)","(23.7638583,90.3640018)","(23.7636919,90.3634078)","(23.7635196,90.3628184)","(23.76334,90.3622084)","(23.7631565,90.361603)","(23.7629617,90.3609961)","(23.7628244,90.3604067)","(23.7626575,90.3598267)","(23.7624946,90.3592463)","(23.7621962,90.3588203)","(23.7617012,90.3589076)","(23.761214,90.3589353)","(23.7607456,90.3589137)","(23.760266,90.3588977)","(23.7597933,90.3589772)","(23.7593013,90.3591863)","(23.7588574,90.3594135)","(23.7584312,90.3596745)","(23.7580374,90.3600035)","(23.7576588,90.3603532)","(23.7572988,90.3607211)","(23.7571017,90.3611683)","(23.7569281,90.3617151)","(23.7564451,90.3623024)","(23.7561139,90.3626807)","(23.7556169,90.3632681)","(23.7550683,90.3639253)","(23.7545584,90.3645602)","(23.7542303,90.3649615)","(23.7537675,90.3654993)","(23.7533922,90.3659314)","(23.7529812,90.3664216)","(23.7525504,90.3669248)","(23.7521677,90.3673378)"}	f	0	rashid56	t	{"2024-04-25 15:08:29.317+06","2024-04-25 15:08:47.622+06","2024-04-25 15:09:08.6+06","2024-04-25 15:09:29.325+06","2024-04-25 15:09:41.099+06","2024-04-25 15:09:59.334+06","2024-04-25 15:10:13.433+06","2024-04-25 15:10:29.348+06","2024-04-25 15:10:44.612+06","2024-04-25 15:10:59.336+06"}
3932	2024-04-25 15:12:00.50411+06	5	morning	{"(36,\\"2024-04-25 15:12:25.113+06\\")","(37,\\"2024-04-25 15:20:31.92+06\\")","(38,\\"2024-04-25 15:24:17.099+06\\")","(39,\\"2024-04-25 15:27:12.01+06\\")","(40,\\"2024-04-25 15:30:02+06\\")",NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-25 20:39:44.920916+06	(23.7660467,90.36494)	(23.7325402,90.3863148)	{"(23.7660467,90.36494)","(23.7660259,90.3649482)","(23.7655784,90.365128)","(23.7649995,90.3653267)","(23.7643742,90.3655247)","(23.7641359,90.3649969)","(23.7640004,90.3645185)","(23.7638267,90.3638835)","(23.7636499,90.3632703)","(23.7634782,90.3626717)","(23.7632952,90.3620657)","(23.7631353,90.3615257)","(23.7629538,90.3609139)","(23.7628038,90.3603303)","(23.7626338,90.3597502)","(23.7624557,90.3591793)","(23.7620042,90.3588847)","(23.7615046,90.3589169)","(23.7610035,90.3589301)","(23.7605183,90.3588808)","(23.7599772,90.3589367)","(23.7595065,90.3590895)","(23.7590116,90.3593332)","(23.7586062,90.3595606)","(23.7581848,90.3598804)","(23.7577783,90.3602032)","(23.757437,90.3605926)","(23.7570574,90.3609361)","(23.7570194,90.3615046)","(23.7566362,90.3620766)","(23.7562999,90.3624709)","(23.7558266,90.3630185)","(23.7555133,90.3633926)","(23.7550135,90.3639916)","(23.7541771,90.3650232)","(23.7536815,90.3655991)","(23.7533388,90.3659933)","(23.7528972,90.3665219)","(23.7524985,90.3669866)","(23.7521015,90.3673854)","(23.7515453,90.3677882)","(23.7510869,90.368115)","(23.7505117,90.3685066)","(23.7501046,90.3687875)","(23.7494752,90.3692233)","(23.7488501,90.36966)","(23.7481387,90.3701451)","(23.7474618,90.3706)","(23.7468215,90.3710301)","(23.7464103,90.371315)","(23.7458282,90.3716935)","(23.7453453,90.3720299)","(23.7448886,90.3723328)","(23.7442813,90.3727197)","(23.743848,90.3730132)","(23.7432888,90.3734004)","(23.7428583,90.3736877)","(23.7422161,90.3740494)","(23.7414983,90.3744264)","(23.7407573,90.3748029)","(23.7400703,90.375148)","(23.7396249,90.3753632)","(23.739017,90.375694)","(23.7385396,90.3759499)","(23.7383369,90.3764059)","(23.7384869,90.3758637)","(23.7389804,90.3755868)","(23.739448,90.3753399)","(23.7388719,90.3757616)","(23.7384822,90.3760164)","(23.73847,90.3769099)","(23.7385268,90.3774151)","(23.7386047,90.3780864)","(23.7387076,90.378798)","(23.7388064,90.3793047)","(23.7389089,90.3798058)","(23.7389985,90.3803585)","(23.7390982,90.380861)","(23.7396585,90.3807454)","(23.74018,90.3809025)","(23.7403281,90.3816693)","(23.7404849,90.3824814)","(23.7405253,90.3831372)","(23.7398619,90.3832617)","(23.7394032,90.3833487)","(23.7388432,90.3834792)","(23.7381988,90.3836458)","(23.7375596,90.3838146)","(23.7369039,90.3839565)","(23.7362789,90.3840831)","(23.7356402,90.3842399)","(23.7349819,90.3844216)","(23.7343519,90.3845767)","(23.7337253,90.3847299)","(23.7331069,90.3848999)","(23.7325396,90.3851794)","(23.7324793,90.3858562)","(37.4220936,-122.083922)","(23.7325684,90.3864933)"}	f	0	rashid56	t	{"2024-04-25 15:38:46.657+06","2024-04-25 15:39:08.501+06","2024-04-25 15:39:29.084+06","2024-04-25 15:39:49.591+06","2024-04-25 15:40:10.123+06","2024-04-25 15:40:30.124+06","2024-04-25 15:40:50.752+06","2024-04-25 15:41:12.126+06","2024-04-25 20:39:32.524+06","2024-04-25 20:39:42.019+06"}
3956	2024-04-25 20:41:10.940975+06	5	morning	{"(36,\\"2024-04-25 20:41:36.628+06\\")","(37,\\"2024-04-25 20:49:32.383+06\\")","(38,\\"2024-04-25 20:53:22.398+06\\")","(39,\\"2024-04-25 20:56:24.634+06\\")","(40,\\"2024-04-25 20:59:12.438+06\\")","(70,\\"2024-04-25 21:13:28.627+06\\")"}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-25 21:20:26.288516+06	(23.76613,90.36491)	(23.7275675,90.3917015)	{"(23.76613,90.36491)","(23.7661085,90.3649185)","(23.7650411,90.3653133)","(23.7645901,90.3654602)","(23.7641801,90.3651579)","(23.7640148,90.3645748)","(23.76385,90.3639718)","(23.7636733,90.3633504)","(23.7635113,90.3627884)","(23.7633317,90.3621802)","(23.7631481,90.3615732)","(23.7629678,90.3609575)","(23.7628204,90.3603892)","(23.7626508,90.3598096)","(23.7625024,90.3592588)","(23.7621811,90.3588218)","(23.7616873,90.3589085)","(23.7612239,90.358931)","(23.7607328,90.3589116)","(23.7602296,90.3589002)","(23.7597685,90.3589848)","(23.7593014,90.3591864)","(23.7588551,90.3594166)","(23.7584078,90.3596883)","(23.758027,90.3600136)","(23.7576477,90.3603639)","(23.7572968,90.3607401)","(23.7570953,90.3611831)","(23.7569178,90.3617496)","(23.7564971,90.3622437)","(23.7560855,90.3627173)","(23.7556434,90.3632366)","(23.7553057,90.3636421)","(23.7548351,90.364213)","(23.7545309,90.3645935)","(23.7540437,90.3651784)","(23.7534935,90.3658133)","(23.7529545,90.3664535)","(23.7524207,90.3670782)","(23.7518149,90.3675983)","(23.7513834,90.3679047)","(23.7508229,90.368292)","(23.7503184,90.3686401)","(23.749844,90.3689677)","(23.7492801,90.3693584)","(23.748865,90.3696494)","(23.7482372,90.3700782)","(23.7475618,90.3705333)","(23.7468701,90.371)","(23.7462348,90.3714362)","(23.7458063,90.3717182)","(23.7452491,90.3720961)","(23.7447541,90.3724098)","(23.7442491,90.3727377)","(23.7437168,90.3731001)","(23.7432549,90.3734231)","(23.7426999,90.3737902)","(23.7422515,90.3740331)","(23.7415664,90.3743859)","(23.7408234,90.3747673)","(23.7401449,90.3751049)","(23.7396951,90.3753252)","(23.739089,90.3756566)","(23.738595,90.3759166)","(23.7383485,90.376349)","(23.7385558,90.3757959)","(23.7390267,90.3755607)","(23.7394481,90.3753399)","(23.7388742,90.3757612)","(23.7382104,90.3762925)","(23.7383962,90.3768019)","(23.738527,90.3774123)","(23.7386341,90.3782132)","(23.7387089,90.3788059)","(23.7388075,90.3793087)","(23.7389099,90.3798091)","(23.7390226,90.3804432)","(23.7391261,90.3809407)","(23.7396595,90.3807467)","(23.7401035,90.380644)","(23.7402413,90.3812213)","(23.7403414,90.3817268)","(23.7404784,90.382443)","(23.7406143,90.383121)","(23.7399248,90.3832504)","(23.7392862,90.3833829)","(23.7386807,90.3835067)","(23.7381041,90.3836762)","(23.7374636,90.3838377)","(23.7368389,90.3839692)","(23.7363719,90.3840602)","(23.7359106,90.3841695)","(23.735408,90.3843064)","(23.7347367,90.3844867)","(23.7341245,90.3846254)","(23.7334787,90.3847984)","(23.7328392,90.38497)","(23.7323303,90.3852695)","(23.7324497,90.3857438)","(23.7325528,90.3864022)","(23.7326454,90.3870653)","(23.7322366,90.3873109)","(23.7318894,90.3869442)","(23.731363,90.3869439)","(23.7308561,90.3870544)","(23.7303794,90.3872185)","(23.7299138,90.3874214)","(23.7294767,90.387662)","(23.7290698,90.3880089)","(23.7286862,90.3883658)","(23.7281131,90.3889449)","(23.7277051,90.3893534)","(23.7272187,90.3897457)","(23.7275486,90.3901247)","(23.7277011,90.3906562)","(23.727888,90.3911903)","(23.728055,90.3916679)","(23.7275877,90.3917008)"}	f	0	rashid56	t	{"2024-04-25 21:12:22.525+06","2024-04-25 21:12:32.509+06","2024-04-25 21:12:47.25+06","2024-04-25 21:12:58.096+06","2024-04-25 21:13:12.527+06","2024-04-25 21:13:28.627+06","2024-04-25 21:13:39.127+06","2024-04-25 21:13:50.124+06","2024-04-25 21:14:00.852+06","2024-04-25 21:14:21.193+06"}
3980	2024-04-25 21:33:14.15366+06	5	morning	{"(36,\\"2024-04-25 21:33:15.573+06\\")","(37,\\"2024-04-25 21:37:15.567+06\\")","(38,\\"2024-04-25 21:38:15.554+06\\")","(39,\\"2024-04-25 21:39:05.579+06\\")","(40,\\"2024-04-25 21:39:44.42+06\\")",NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-26 00:51:39.32545+06	(23.765385,90.365185)	(23.7399523,90.3832421)	{"(23.765385,90.365185)","(23.7653629,90.3651932)","(23.7647903,90.3653963)","(23.7643364,90.3655352)","(23.7641311,90.3649808)","(23.76395,90.3643401)","(23.7637817,90.3637067)","(23.7636066,90.363123)","(23.7634397,90.3625299)","(23.7630639,90.361309)","(23.7628661,90.3604862)","(23.7624596,90.3590773)","(23.7620677,90.3579881)","(23.7605896,90.3590235)","(23.7597228,90.358889)","(23.7587253,90.3593622)","(23.7579259,90.3599842)","(23.7572109,90.3607906)","(23.7568151,90.3617863)","(23.7560966,90.3628892)","(23.7547094,90.364338)","(23.7537525,90.3655423)","(23.7526767,90.3667717)","(23.7515203,90.3679306)","(23.750185,90.3687397)","(23.7488831,90.3696342)","(23.7475816,90.370522)","(23.7463987,90.3713182)","(23.7449237,90.3723176)","(23.7437838,90.3730481)","(23.7422895,90.3740678)","(23.7410201,90.3746718)","(23.7396616,90.3753447)","(23.738291,90.3762658)","(23.7372215,90.3768073)","(23.739641,90.3749808)","(23.740053,90.375411)","(23.7393472,90.3755308)","(23.7388047,90.3758002)","(23.7383762,90.3762777)","(23.7384785,90.3769721)","(23.7385572,90.3776877)","(23.7386347,90.3781755)","(23.7386991,90.3787301)","(23.7387921,90.3792268)","(23.7389769,90.3801837)","(23.7390734,90.3806923)","(23.7395328,90.3808263)","(23.7399763,90.380673)","(23.7402346,90.3810868)","(23.7403213,90.3816301)","(23.7404391,90.3822218)","(23.74055,90.3828229)","(23.7401641,90.3832148)","(23.7396503,90.3832882)"}	f	0	rashid56	t	{"2024-04-25 21:42:35.306+06","2024-04-25 21:42:46.111+06","2024-04-25 21:43:05.589+06","2024-04-25 21:43:17.609+06","2024-04-25 21:43:35.584+06","2024-04-25 21:43:49.103+06","2024-04-25 21:44:05.639+06","2024-04-25 21:44:20.642+06","2024-04-25 21:44:45.615+06","2024-04-25 21:46:05.615+06"}
4004	2024-04-26 02:21:56.458825+06	5	morning	{"(36,\\"2024-04-26 02:21:57.78+06\\")","(37,\\"2024-04-26 02:30:07.906+06\\")","(38,\\"2024-04-26 02:33:37.909+06\\")",NULL,NULL,NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-26 12:39:54.09223+06	(23.7651667,90.3652733)	(23.7511526,90.3680644)	{"(23.7651667,90.3652733)","(23.7651488,90.3652792)","(23.7646936,90.3654333)","(23.7642415,90.3653926)","(23.7640651,90.3647514)","(23.7638933,90.3641334)","(23.7637267,90.3635245)","(23.7635485,90.3629207)","(23.7633765,90.3623223)","(23.7632028,90.3617594)","(23.7630315,90.3611819)","(23.76288,90.3606216)","(23.7627241,90.3600371)","(23.7625473,90.3594338)","(23.7623608,90.3588591)","(23.7618562,90.358899)","(23.7613712,90.3589263)","(23.76088,90.3589301)","(23.7604164,90.3588857)","(23.7599291,90.3589456)","(23.7594814,90.3590997)","(23.7589882,90.3593448)","(23.7585863,90.3595711)","(23.7581641,90.359899)","(23.7577589,90.3602174)","(23.757421,90.3606104)","(23.7570396,90.3609536)","(23.7570414,90.3614504)","(23.756586,90.3621402)","(23.7560609,90.3627412)","(23.7554867,90.363425)","(23.7549628,90.3640558)","(23.7544555,90.3646896)","(23.7541506,90.3650548)","(23.7536688,90.3656144)","(23.7532866,90.3660536)","(23.7528896,90.3665315)","(23.7524452,90.3670482)","(23.7520511,90.3674161)","(23.7514472,90.3678581)","(37.4220936,-122.083922)","(23.7509612,90.3681983)"}	f	0	rashid56	t	{"2024-04-26 02:32:07.916+06","2024-04-26 02:32:19.096+06","2024-04-26 02:32:37.915+06","2024-04-26 02:32:51.604+06","2024-04-26 02:33:07.922+06","2024-04-26 02:33:23.61+06","2024-04-26 02:33:37.91+06","2024-04-26 02:33:55.605+06","2024-04-26 12:38:56.19+06","2024-04-26 12:39:05.563+06"}
4028	2024-04-26 12:40:42.752974+06	5	morning	{"(36,\\"2024-04-26 12:41:18.771+06\\")",NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-26 12:43:32.586673+06	(23.76584,90.3650183)	(23.7634538,90.3625778)	{"(23.76584,90.3650183)","(23.765818,90.365027)","(23.7662266,90.3646322)","(23.7659087,90.3649895)","(23.7652789,90.3652286)","(23.7648318,90.3653823)","(23.7643781,90.3655219)","(23.7641306,90.3649807)","(23.7638,90.3637759)","(23.7636277,90.3632004)","(23.7634591,90.362623)"}	f	0	rashid56	t	{"2024-04-26 12:40:44.181+06","2024-04-26 12:40:54.142+06","2024-04-26 12:41:04.142+06","2024-04-26 12:41:18.771+06","2024-04-26 12:41:29.724+06","2024-04-26 12:41:40.707+06","2024-04-26 12:42:02.202+06","2024-04-26 12:42:44.169+06","2024-04-26 12:43:04.162+06","2024-04-26 12:43:24.163+06"}
4052	2024-04-26 12:50:26.566846+06	5	morning	{"(36,\\"2024-04-26 12:50:53.207+06\\")",NULL,NULL,NULL,NULL,NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-26 12:51:27.571719+06	(23.7660883,90.364925)	(23.7641628,90.3650982)	{"(23.7660883,90.364925)","(23.7658845,90.3650041)","(23.7654353,90.3651837)","(23.7649578,90.36534)","(23.7642341,90.3655646)"}	f	0	rashid56	t	{"2024-04-26 12:50:26.566+06","2024-04-26 12:50:32.357+06","2024-04-26 12:50:42.368+06","2024-04-26 12:50:53.208+06","2024-04-26 12:51:12.376+06"}
4076	2024-04-26 12:57:46.272095+06	5	morning	{"(36,\\"2024-04-26 12:58:17.666+06\\")","(37,\\"2024-04-26 13:06:07.703+06\\")","(38,\\"2024-04-26 13:10:02.826+06\\")","(39,\\"2024-04-26 13:13:07.758+06\\")","(40,\\"2024-04-26 13:15:42.217+06\\")",NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-26 14:37:54.120459+06	(23.76614,90.3649067)	(23.7380302,90.3836953)	{"(23.76614,90.3649067)","(23.766118,90.364914)","(23.7655548,90.3651241)","(23.7649246,90.3653548)","(23.7644715,90.365501)","(23.7641585,90.3651017)","(23.763998,90.364512)","(23.7638583,90.3640018)","(23.7636821,90.3633787)","(23.7635196,90.3628183)","(23.76334,90.3622084)","(23.7631566,90.3616031)","(23.7628304,90.3604269)","(23.7626632,90.3598468)","(23.7625007,90.359268)","(23.7623082,90.3587264)","(23.7618705,90.3588947)","(23.7613585,90.3589252)","(23.7608683,90.3589296)","(23.7603631,90.3588909)","(23.7598499,90.3589614)","(23.7593465,90.3591647)","(23.7584466,90.3596634)","(23.7580515,90.3599917)","(23.7576714,90.3603397)","(23.7573122,90.3607085)","(23.7571029,90.3611493)","(23.7569485,90.3616935)","(23.7564974,90.3622434)","(23.7561342,90.362661)","(23.7556701,90.3632049)","(23.7553524,90.3635862)","(23.7548602,90.3641815)","(23.7543234,90.3648516)","(23.7537813,90.3654862)","(23.753467,90.3658449)","(23.753031,90.3663605)","(23.7526304,90.3668318)","(23.752202,90.367333)","(23.7516753,90.3676949)","(23.7512162,90.3680259)","(23.7506101,90.3684383)","(23.7499021,90.3689267)","(23.7492186,90.3694046)","(23.7485944,90.3698393)","(23.7482039,90.3700999)","(23.7476056,90.3705048)","(23.7471319,90.3708216)","(23.7466178,90.3711742)","(23.7460952,90.3715202)","(23.7456367,90.3718342)","(23.7450584,90.3722304)","(23.7446435,90.3724748)","(23.7440135,90.3729)","(23.7433035,90.3733881)","(23.742632,90.3738413)","(23.7419571,90.3741767)","(23.7414984,90.3744262)","(23.7409053,90.3747269)","(23.740374,90.3749925)","(23.7398424,90.3752494)","(23.7392102,90.3755899)","(23.7385134,90.3759789)","(23.7389952,90.3755756)","(23.739452,90.375335)","(23.7390287,90.3756786)","(23.7385732,90.375928)","(23.7384249,90.3766437)","(23.7384947,90.3771403)","(23.738555,90.3776816)","(23.7386887,90.3785874)","(23.7388383,90.3794949)","(23.73895,90.3800352)","(23.7391048,90.3808603)","(23.7397318,90.3807282)","(23.7402147,90.3808717)","(23.7402918,90.3814833)","(23.7404024,90.3820389)","(23.7405201,90.3826714)","(23.7404099,90.3831714)","(23.7397371,90.3832832)","(23.7390856,90.3834217)"}	f	0	rashid56	t	{"2024-04-26 13:20:18.73+06","2024-04-26 13:20:37.805+06","2024-04-26 13:20:57.832+06","2024-04-26 13:21:17.824+06","2024-04-26 13:21:32.197+06","2024-04-26 13:21:47.849+06","2024-04-26 13:22:03.736+06","2024-04-26 13:22:24.21+06","2024-04-26 13:22:45.208+06","2024-04-26 13:23:05.701+06"}
3910	2024-04-26 14:48:12.64186+06	5	afternoon	{"(70,\\"2024-04-26 14:48:14.069+06\\")","(40,\\"2024-04-26 14:59:34.081+06\\")","(39,\\"2024-04-26 15:00:39.611+06\\")","(38,\\"2024-04-26 15:02:04.104+06\\")","(37,\\"2024-04-26 15:03:44.125+06\\")","(36,\\"2024-04-26 15:08:14.109+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	2024-04-26 15:15:40.35258+06	(23.7273567,90.3917133)	(23.7633262,90.3643271)	{"(23.7273567,90.3917133)","(23.7273447,90.391714)","(23.7267851,90.3917)","(23.72632,90.3917683)","(23.7258698,90.39184)","(23.7260389,90.3913849)","(23.7263297,90.3909282)","(23.726622,90.3905075)","(23.7269286,90.3900932)","(23.7272432,90.3896712)","(23.7278578,90.3890843)","(23.7282785,90.3887679)","(23.7286839,90.3883752)","(23.7290611,90.3880385)","(23.7294782,90.3877047)","(23.7299327,90.3874376)","(23.7304162,90.3872359)","(23.7308636,90.3870846)","(23.7313858,90.3869709)","(23.7319558,90.386892)","(23.7324648,90.3869453)","(23.7324624,90.3863623)","(23.7323666,90.3856392)","(23.7322724,90.3849681)","(23.7327926,90.3848589)","(23.7333788,90.38469)","(23.7338732,90.3845449)","(23.7343794,90.3844362)","(23.7348945,90.3843129)","(23.7354253,90.3841717)","(23.7359816,90.384015)","(23.7364511,90.3838971)","(23.737083,90.38376)","(23.7378502,90.3835798)","(23.7385501,90.3834098)","(23.7392271,90.3832813)","(23.739441,90.3827164)","(23.739243,90.3820217)","(23.7391501,90.3815093)","(23.7390317,90.3808775)","(23.7389235,90.3803222)","(23.7388039,90.3797546)","(23.7386783,90.3791418)","(23.7385875,90.37863)","(23.7385165,90.3779933)","(23.7384552,90.3775022)","(23.7382655,90.3757717)","(23.7397108,90.3751321)","(23.7406136,90.3747243)","(23.7413649,90.3743367)","(23.7421394,90.3739513)","(23.7428206,90.3735701)","(23.7435315,90.3730901)","(23.7443459,90.3725377)","(23.7450436,90.3720424)","(23.745651,90.3716209)","(23.7464326,90.371131)","(23.7470577,90.3707165)","(23.747774,90.370247)","(23.7485638,90.3696899)","(23.7492456,90.3692064)","(23.7499577,90.3687363)","(23.7506901,90.3682353)","(23.7514012,90.3677516)","(23.7520925,90.3672558)","(23.7527108,90.3666922)","(23.7532415,90.3659951)","(23.7538007,90.3653457)","(23.7542948,90.3647611)","(23.7549082,90.3640214)","(23.7554579,90.3633619)","(23.7560217,90.362699)","(23.7565918,90.3620163)","(23.7570412,90.3612894)","(23.7569768,90.3604657)","(23.7566339,90.359399)","(23.757098,90.3611672)","(23.7577623,90.3625321)","(23.7586766,90.3641755)","(23.7590157,90.3648709)","(23.7593148,90.36553)","(23.759843,90.3655477)","(23.7603399,90.3653885)","(23.7608247,90.3651783)","(23.7613301,90.3650104)","(23.7618251,90.3648437)","(23.7623529,90.3646585)","(23.7628491,90.3644862)","(37.4220936,-122.083922)","(23.7634424,90.364283)"}	f	0	mahbub777	t	{"2024-04-26 15:05:44.118+06","2024-04-26 15:06:06.611+06","2024-04-26 15:06:27.596+06","2024-04-26 15:06:48.606+06","2024-04-26 15:07:10.112+06","2024-04-26 15:07:31.218+06","2024-04-26 15:07:53.121+06","2024-04-26 15:08:14.109+06","2024-04-26 15:15:22.867+06","2024-04-26 15:15:32.326+06"}
3934	2024-04-26 15:17:43.360973+06	5	afternoon	{"(70,\\"2024-04-26 15:17:44.791+06\\")",NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	2024-04-26 15:19:37.644809+06	(23.7273567,90.3917133)	(23.7269474,90.3900674)	{"(23.7273567,90.3917133)","(23.7273433,90.3917141)","(23.7267851,90.3917)","(23.7262518,90.3917788)","(23.7260694,90.3913131)","(23.7263603,90.390881)","(23.7269286,90.3900932)"}	f	0	mahbub777	t	{"2024-04-26 15:17:43.36+06","2024-04-26 15:17:44.791+06","2024-04-26 15:18:09.314+06","2024-04-26 15:18:34.756+06","2024-04-26 15:19:04.756+06","2024-04-26 15:19:14.765+06","2024-04-26 15:19:33.288+06"}
3958	2024-04-26 15:20:07.338696+06	5	afternoon	{"(70,\\"2024-04-26 15:20:08.759+06\\")",NULL,NULL,NULL,NULL,NULL}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	2024-04-26 15:22:26.851729+06	(23.7273783,90.3917117)	(23.7276913,90.3892673)	{"(23.7273783,90.3917117)","(23.727367,90.3917123)","(23.72683,90.3917017)","(23.7263634,90.3917616)","(23.7258582,90.3918432)","(23.726037,90.3913623)","(23.7265601,90.3905949)","(23.7268699,90.3901725)","(23.7271586,90.3897949)","(23.727442,90.3894126)"}	f	0	mahbub777	t	{"2024-04-26 15:20:07.338+06","2024-04-26 15:20:08.759+06","2024-04-26 15:20:32.331+06","2024-04-26 15:20:53.84+06","2024-04-26 15:21:18.737+06","2024-04-26 15:21:28.73+06","2024-04-26 15:21:45.842+06","2024-04-26 15:21:56.33+06","2024-04-26 15:22:06.777+06","2024-04-26 15:22:16.916+06"}
3982	2024-04-26 15:40:13.335864+06	5	afternoon	{"(70,\\"2024-04-26 15:40:16.182+06\\")","(40,\\"2024-04-26 15:51:52.809+06\\")","(39,\\"2024-04-26 15:54:26.302+06\\")","(38,\\"2024-04-26 15:57:26.316+06\\")","(37,\\"2024-04-26 16:00:46.34+06\\")","(36,\\"2024-04-26 16:08:48.827+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	2024-04-26 16:13:25.922433+06	(23.7274,90.39171)	(23.76443,90.36544)	{"(23.7274,90.39171)","(23.7273565,90.3917125)","(23.7267854,90.3917)","(23.7263104,90.3917692)","(23.726303,90.3909703)","(23.7265897,90.390552)","(23.7268997,90.3901319)","(23.7271936,90.3897444)","(23.7278573,90.3890948)","(23.7282235,90.3887839)","(23.7286612,90.3883987)","(23.729097,90.3880145)","(23.7294723,90.3877162)","(23.7299196,90.3874629)","(23.7303602,90.387276)","(23.7308395,90.3871065)","(23.7313645,90.3869869)","(23.7321798,90.3869179)","(23.7324801,90.3864973)","(23.7323851,90.3857754)","(23.73229,90.3850502)","(23.7330015,90.3848)","(23.7334856,90.3846687)","(23.7340861,90.3844869)","(23.7345723,90.3844192)","(23.7351241,90.3842522)","(23.7355893,90.3841379)","(23.7362079,90.3839507)","(23.7366659,90.3838622)","(23.7373645,90.3836935)","(23.7380748,90.3835201)","(23.7388297,90.38336)","(23.7394749,90.3831552)","(23.7393233,90.3823818)","(23.7391735,90.3816201)","(23.7390832,90.3810875)","(23.738948,90.3804379)","(23.7388481,90.3799246)","(23.7387005,90.3792536)","(23.7386156,90.3787614)","(23.7385201,90.3780305)","(23.7384383,90.3772654)","(23.7383234,90.3765036)","(23.7384995,90.3758599)","(23.7392446,90.3754486)","(23.7400148,90.3750433)","(23.7407472,90.3746598)","(23.7411621,90.3744436)","(23.7416647,90.3742039)","(23.7423335,90.3738651)","(23.7427391,90.373626)","(23.743195,90.3733238)","(23.7435793,90.373066)","(23.7442417,90.3726145)","(23.7446658,90.372299)","(23.7453477,90.3718539)","(23.745763,90.3715871)","(23.7464695,90.3711005)","(23.7468785,90.370838)","(23.7476247,90.3703419)","(23.7483598,90.3698302)","(23.7490881,90.3693183)","(23.7498209,90.3688311)","(23.7503137,90.36851)","(23.7509195,90.368079)","(23.7513152,90.3678134)","(23.7517589,90.3675157)","(23.7523776,90.3669923)","(23.7526968,90.3666284)","(23.7530091,90.3662659)","(23.7533483,90.3658703)","(23.7539346,90.3651905)","(23.7542563,90.3647999)","(23.7548347,90.3641103)","(23.7551415,90.3637419)","(23.7557049,90.3630766)","(23.7560166,90.3627067)","(23.7563934,90.3622486)","(23.7569194,90.3616212)","(23.7570381,90.3610563)","(23.756926,90.3603985)","(23.7568052,90.3599141)","(23.7565721,90.3592544)","(23.7568598,90.3597199)","(23.7570349,90.3604363)","(23.7571234,90.3610134)","(23.7571004,90.3616193)","(23.7575423,90.3622102)","(23.7578247,90.3626387)","(23.7581498,90.3631811)","(23.7585174,90.3638635)","(23.7588566,90.3645434)","(23.7590604,90.3649812)","(23.7593577,90.3656138)","(23.7598193,90.3655535)","(23.7603397,90.3653884)","(23.7608248,90.3651784)","(23.7613315,90.3650101)","(23.7618254,90.3648432)","(23.7623488,90.3646601)","(23.7628448,90.3644874)","(23.7633287,90.3643238)","(23.7638124,90.3641471)","(23.764048,90.3646892)","(23.7642349,90.3653563)","(37.4220936,-122.083922)"}	f	0	mahbub777	t	{"2024-04-26 16:07:23.314+06","2024-04-26 16:07:44.827+06","2024-04-26 16:08:11.589+06","2024-04-26 16:08:27.825+06","2024-04-26 16:08:48.827+06","2024-04-26 16:09:09.302+06","2024-04-26 16:09:29.829+06","2024-04-26 16:09:50.836+06","2024-04-26 16:10:11.827+06","2024-04-26 16:13:20.218+06"}
4100	2024-04-26 16:25:02.38618+06	5	morning	{"(36,\\"2024-04-26 16:25:18.81+06\\")","(37,\\"2024-04-26 16:33:09.299+06\\")","(38,\\"2024-04-26 16:36:50.817+06\\")","(39,\\"2024-04-26 16:40:13.328+06\\")","(40,\\"2024-04-26 16:42:39.841+06\\")",NULL}	to_buet	Ba-24-8518	t	nizam88	nazmul	2024-04-26 18:22:58.685573+06	(23.7654267,90.36517)	(23.7389117,90.3756267)	{"(23.7654267,90.36517)","(23.7653979,90.3651785)","(23.7647498,90.3654077)","(23.7642499,90.3655511)","(23.7641319,90.3649806)","(23.7639585,90.3643687)","(23.7637884,90.3637352)","(23.7636146,90.36315)","(23.76344,90.3625301)","(23.76326,90.3619468)","(23.76308,90.3613405)","(23.7629047,90.3607167)","(23.7627443,90.3601166)","(23.7625688,90.3595065)","(23.7623804,90.3589195)","(23.7619205,90.3588917)","(23.7613821,90.3589233)","(23.7608753,90.35893)","(23.7603901,90.35889)","(23.759875,90.3589549)","(23.75937,90.3591532)","(23.7588824,90.3594018)","(23.7584488,90.3596706)","(23.7580096,90.360019)","(23.7576256,90.3603944)","(23.7572472,90.3607629)","(23.7570801,90.3612663)","(23.7567602,90.3619126)","(23.7562321,90.3625463)","(23.7556954,90.3631746)","(23.7551469,90.3638315)","(23.7547694,90.3643039)","(23.7543174,90.3648608)","(23.753957,90.3652806)","(23.7534692,90.3658421)","(23.7529298,90.3664849)","(23.7525905,90.3668796)","(23.7520156,90.3674364)","(23.7516435,90.3677156)","(23.7509703,90.3681915)","(23.7502851,90.3686617)","(23.7498008,90.3689812)","(23.7492518,90.3693817)","(23.7488155,90.3696711)","(23.7482065,90.3700977)","(23.7477934,90.3703645)","(23.7471662,90.3707991)","(23.7467536,90.3710743)","(23.7460954,90.3715197)","(23.7453785,90.3720081)","(23.7446843,90.3724498)","(23.7442122,90.3727518)","(23.7436009,90.3731787)","(23.7432095,90.3734431)","(23.7425818,90.3738687)","(23.7421346,90.3740739)","(23.7414995,90.3744259)","(23.7410708,90.3746341)","(23.7404074,90.3749745)","(23.7399884,90.3751725)","(23.739349,90.3755128)","(23.7389358,90.375723)","(23.7384001,90.3761895)","(23.7386632,90.3757467)","(37.4220936,-122.083922)"}	f	0	rashid56	t	{"2024-04-26 16:41:55.046+06","2024-04-26 16:42:08.814+06","2024-04-26 16:42:25.061+06","2024-04-26 16:42:39.841+06","2024-04-26 16:42:55.051+06","2024-04-26 16:43:09.827+06","2024-04-26 16:43:25.039+06","2024-04-26 16:43:41.609+06","2024-04-26 16:44:12.676+06","2024-04-26 18:22:52.469+06"}
4124	2024-04-26 18:26:41.872292+06	5	morning	{"(36,\\"2024-04-28 12:30:00+06\\")","(37,\\"2024-04-28 12:33:00+06\\")","(38,\\"2024-04-28 12:40:00+06\\")","(39,\\"2024-04-28 12:45:00+06\\")","(40,\\"2024-04-28 12:50:00+06\\")","(70,\\"2024-04-28 13:00:00+06\\")"}	to_buet	Ba-24-8518	t	nizam88	nazmul	\N	(23.7659633,90.3649717)	\N	\N	t	0	rashid56	t	\N
4102	2024-04-26 18:34:18.37698+06	5	afternoon	{"(36,\\"2024-04-27 19:40:00+06\\")","(37,\\"2024-04-27 19:50:00+06\\")","(38,\\"2024-04-27 19:55:00+06\\")","(39,\\"2024-04-27 20:00:00+06\\")","(40,\\"2024-04-27 20:07:00+06\\")","(70,\\"2024-04-27 20:10:00+06\\")"}	from_buet	Ba-20-3066	t	rahmatullah	nazmul	\N	(23.727335,90.391715)	\N	\N	t	0	mahbub777	t	\N
\.


--
-- Name: assignment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.assignment_id_seq', 184, true);


--
-- Name: broadcast_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.broadcast_notification_id_seq', 32, true);


--
-- Name: feedback_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.feedback_id_seq', 66, true);


--
-- Name: notice_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notice_id_seq', 15, true);


--
-- Name: purchase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.purchase_id_seq', 86, true);


--
-- Name: repair_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.repair_id_seq', 7, true);


--
-- Name: requisition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.requisition_id_seq', 47, true);


--
-- Name: student_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.student_notification_id_seq', 149, true);


--
-- Name: upcoming_trip_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.upcoming_trip_id_seq', 4275, true);


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
-- Name: broadcast_notification broadcast_notification_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.broadcast_notification
    ADD CONSTRAINT broadcast_notification_pkey PRIMARY KEY (id);


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
-- Name: notice notice_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notice
    ADD CONSTRAINT notice_pkey PRIMARY KEY (id);


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
-- Name: personal_notification student_notification_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_notification
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
    ADD CONSTRAINT assignment_driver_fkey FOREIGN KEY (driver) REFERENCES public.bus_staff(id);


--
-- Name: assignment assignment_helper_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignment
    ADD CONSTRAINT assignment_helper_fkey FOREIGN KEY (helper) REFERENCES public.bus_staff(id);


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
-- Name: requisition requisition_allocation_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requisition
    ADD CONSTRAINT requisition_allocation_fkey FOREIGN KEY (allocation_id) REFERENCES public.allocation(id) ON UPDATE CASCADE ON DELETE SET NULL;


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
-- Name: schedule schedule_bus_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_bus_fkey FOREIGN KEY (default_bus) REFERENCES public.bus(reg_id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- Name: schedule schedule_driver_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_driver_fkey FOREIGN KEY (default_driver) REFERENCES public.bus_staff(id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- Name: schedule schedule_helper_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_helper_fkey FOREIGN KEY (default_helper) REFERENCES public.bus_staff(id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


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

