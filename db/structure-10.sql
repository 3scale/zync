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
-- Name: integration_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.integration_state AS ENUM (
    'active',
    'disabled'
);


--
-- Name: que_validate_tags(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_validate_tags(tags_array jsonb) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT bool_and(
    jsonb_typeof(value) = 'string'
    AND
    char_length(value::text) <= 100
  )
  FROM jsonb_array_elements(tags_array)
$$;


SET default_tablespace = '';

--
-- Name: que_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.que_jobs (
    priority smallint DEFAULT 100 NOT NULL,
    run_at timestamp with time zone DEFAULT now() NOT NULL,
    id bigint NOT NULL,
    job_class text NOT NULL,
    error_count integer DEFAULT 0 NOT NULL,
    last_error_message text,
    queue text DEFAULT 'default'::text NOT NULL,
    last_error_backtrace text,
    finished_at timestamp with time zone,
    expired_at timestamp with time zone,
    args jsonb DEFAULT '[]'::jsonb NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    job_schema_version integer DEFAULT 1,
    CONSTRAINT error_length CHECK (((char_length(last_error_message) <= 500) AND (char_length(last_error_backtrace) <= 10000))),
    CONSTRAINT job_class_length CHECK ((char_length(
CASE job_class
    WHEN 'ActiveJob::QueueAdapters::QueAdapter::JobWrapper'::text THEN ((args -> 0) ->> 'job_class'::text)
    ELSE job_class
END) <= 200)),
    CONSTRAINT queue_length CHECK ((char_length(queue) <= 100)),
    CONSTRAINT valid_args CHECK ((jsonb_typeof(args) = 'array'::text)),
    CONSTRAINT valid_data CHECK (((jsonb_typeof(data) = 'object'::text) AND ((NOT (data ? 'tags'::text)) OR ((jsonb_typeof((data -> 'tags'::text)) = 'array'::text) AND (jsonb_array_length((data -> 'tags'::text)) <= 5) AND public.que_validate_tags((data -> 'tags'::text))))))
)
WITH (fillfactor='90');


--
-- Name: TABLE que_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.que_jobs IS '5';


--
-- Name: que_determine_job_state(public.que_jobs); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_determine_job_state(job public.que_jobs) RETURNS text
    LANGUAGE sql
    AS $$
  SELECT
    CASE
    WHEN job.expired_at  IS NOT NULL    THEN 'expired'
    WHEN job.finished_at IS NOT NULL    THEN 'finished'
    WHEN job.error_count > 0            THEN 'errored'
    WHEN job.run_at > CURRENT_TIMESTAMP THEN 'scheduled'
    ELSE                                     'ready'
    END
$$;


--
-- Name: que_job_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_job_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    locker_pid integer;
    sort_key json;
  BEGIN
    -- Don't do anything if the job is scheduled for a future time.
    IF NEW.run_at IS NOT NULL AND NEW.run_at > now() THEN
      RETURN null;
    END IF;

    -- Pick a locker to notify of the job's insertion, weighted by their number
    -- of workers. Should bounce pseudorandomly between lockers on each
    -- invocation, hence the md5-ordering, but still touch each one equally,
    -- hence the modulo using the job_id.
    SELECT pid
    INTO locker_pid
    FROM (
      SELECT *, last_value(row_number) OVER () + 1 AS count
      FROM (
        SELECT *, row_number() OVER () - 1 AS row_number
        FROM (
          SELECT *
          FROM public.que_lockers ql, generate_series(1, ql.worker_count) AS id
          WHERE
            listening AND
            queues @> ARRAY[NEW.queue] AND
            ql.job_schema_version = NEW.job_schema_version
          ORDER BY md5(pid::text || id::text)
        ) t1
      ) t2
    ) t3
    WHERE NEW.id % count = row_number;

    IF locker_pid IS NOT NULL THEN
      -- There's a size limit to what can be broadcast via LISTEN/NOTIFY, so
      -- rather than throw errors when someone enqueues a big job, just
      -- broadcast the most pertinent information, and let the locker query for
      -- the record after it's taken the lock. The worker will have to hit the
      -- DB in order to make sure the job is still visible anyway.
      SELECT row_to_json(t)
      INTO sort_key
      FROM (
        SELECT
          'job_available' AS message_type,
          NEW.queue       AS queue,
          NEW.priority    AS priority,
          NEW.id          AS id,
          -- Make sure we output timestamps as UTC ISO 8601
          to_char(NEW.run_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS run_at
      ) t;

      PERFORM pg_notify('que_listener_' || locker_pid::text, sort_key::text);
    END IF;

    RETURN null;
  END
$$;


--
-- Name: que_state_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_state_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    row record;
    message json;
    previous_state text;
    current_state text;
  BEGIN
    IF TG_OP = 'INSERT' THEN
      previous_state := 'nonexistent';
      current_state  := public.que_determine_job_state(NEW);
      row            := NEW;
    ELSIF TG_OP = 'DELETE' THEN
      previous_state := public.que_determine_job_state(OLD);
      current_state  := 'nonexistent';
      row            := OLD;
    ELSIF TG_OP = 'UPDATE' THEN
      previous_state := public.que_determine_job_state(OLD);
      current_state  := public.que_determine_job_state(NEW);

      -- If the state didn't change, short-circuit.
      IF previous_state = current_state THEN
        RETURN null;
      END IF;

      row := NEW;
    ELSE
      RAISE EXCEPTION 'Unrecognized TG_OP: %', TG_OP;
    END IF;

    SELECT row_to_json(t)
    INTO message
    FROM (
      SELECT
        'job_change' AS message_type,
        row.id       AS id,
        row.queue    AS queue,

        coalesce(row.data->'tags', '[]'::jsonb) AS tags,

        to_char(row.run_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS run_at,
        to_char(now()      AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS time,

        CASE row.job_class
        WHEN 'ActiveJob::QueueAdapters::QueAdapter::JobWrapper' THEN
          coalesce(
            row.args->0->>'job_class',
            'ActiveJob::QueueAdapters::QueAdapter::JobWrapper'
          )
        ELSE
          row.job_class
        END AS job_class,

        previous_state AS previous_state,
        current_state  AS current_state
    ) t;

    PERFORM pg_notify('que_state', message::text);

    RETURN null;
  END
$$;


--
-- Name: applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applications (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    service_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: applications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.applications_id_seq OWNED BY public.applications.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clients (
    id bigint NOT NULL,
    service_id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    client_id character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entries (
    id bigint NOT NULL,
    data jsonb,
    tenant_id bigint NOT NULL,
    model_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entries_id_seq OWNED BY public.entries.id;


--
-- Name: integration_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_states (
    id bigint NOT NULL,
    started_at timestamp without time zone,
    finished_at timestamp without time zone,
    success boolean,
    model_id bigint NOT NULL,
    entry_id bigint,
    integration_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: integration_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.integration_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: integration_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.integration_states_id_seq OWNED BY public.integration_states.id;


--
-- Name: integrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integrations (
    id bigint NOT NULL,
    configuration jsonb,
    type character varying NOT NULL,
    tenant_id bigint,
    model_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    state public.integration_state DEFAULT 'active'::public.integration_state NOT NULL
);


--
-- Name: integrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.integrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: integrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.integrations_id_seq OWNED BY public.integrations.id;


--
-- Name: message_bus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_bus (
    id bigint NOT NULL,
    channel text NOT NULL,
    value text NOT NULL,
    added_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT message_bus_value_check CHECK ((octet_length(value) >= 2))
);


--
-- Name: message_bus_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.message_bus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: message_bus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.message_bus_id_seq OWNED BY public.message_bus.id;


--
-- Name: metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metrics (
    id bigint NOT NULL,
    service_id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.metrics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.metrics_id_seq OWNED BY public.metrics.id;


--
-- Name: models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.models (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: models_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.models_id_seq OWNED BY public.models.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    model_id bigint NOT NULL,
    data jsonb NOT NULL,
    tenant_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: providers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.providers (
    id bigint NOT NULL,
    tenant_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: providers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.providers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: providers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.providers_id_seq OWNED BY public.providers.id;


--
-- Name: proxies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.proxies (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    service_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: proxies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.proxies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: proxies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.proxies_id_seq OWNED BY public.proxies.id;


--
-- Name: que_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.que_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: que_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.que_jobs_id_seq OWNED BY public.que_jobs.id;


--
-- Name: que_lockers; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.que_lockers (
    pid integer NOT NULL,
    worker_count integer NOT NULL,
    worker_priorities integer[] NOT NULL,
    ruby_pid integer NOT NULL,
    ruby_hostname text NOT NULL,
    queues text[] NOT NULL,
    listening boolean NOT NULL,
    job_schema_version integer DEFAULT 1,
    CONSTRAINT valid_queues CHECK (((array_ndims(queues) = 1) AND (array_length(queues, 1) IS NOT NULL))),
    CONSTRAINT valid_worker_priorities CHECK (((array_ndims(worker_priorities) = 1) AND (array_length(worker_priorities, 1) IS NOT NULL)))
);


--
-- Name: que_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.que_values (
    key text NOT NULL,
    value jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT valid_value CHECK ((jsonb_typeof(value) = 'object'::text))
)
WITH (fillfactor='90');


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.services (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: services_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.services_id_seq OWNED BY public.services.id;


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenants (
    id bigint NOT NULL,
    endpoint character varying NOT NULL,
    access_token character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: tenants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tenants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tenants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tenants_id_seq OWNED BY public.tenants.id;


--
-- Name: update_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.update_states (
    id bigint NOT NULL,
    started_at timestamp without time zone,
    finished_at timestamp without time zone,
    success boolean DEFAULT false NOT NULL,
    model_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: update_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.update_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: update_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.update_states_id_seq OWNED BY public.update_states.id;


--
-- Name: usage_limits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_limits (
    id bigint NOT NULL,
    metric_id bigint NOT NULL,
    plan_id integer NOT NULL,
    tenant_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: usage_limits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usage_limits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usage_limits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usage_limits_id_seq OWNED BY public.usage_limits.id;


--
-- Name: applications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications ALTER COLUMN id SET DEFAULT nextval('public.applications_id_seq'::regclass);


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries ALTER COLUMN id SET DEFAULT nextval('public.entries_id_seq'::regclass);


--
-- Name: integration_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_states ALTER COLUMN id SET DEFAULT nextval('public.integration_states_id_seq'::regclass);


--
-- Name: integrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integrations ALTER COLUMN id SET DEFAULT nextval('public.integrations_id_seq'::regclass);


--
-- Name: message_bus id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_bus ALTER COLUMN id SET DEFAULT nextval('public.message_bus_id_seq'::regclass);


--
-- Name: metrics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics ALTER COLUMN id SET DEFAULT nextval('public.metrics_id_seq'::regclass);


--
-- Name: models id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.models ALTER COLUMN id SET DEFAULT nextval('public.models_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: providers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.providers ALTER COLUMN id SET DEFAULT nextval('public.providers_id_seq'::regclass);


--
-- Name: proxies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proxies ALTER COLUMN id SET DEFAULT nextval('public.proxies_id_seq'::regclass);


--
-- Name: que_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_jobs ALTER COLUMN id SET DEFAULT nextval('public.que_jobs_id_seq'::regclass);


--
-- Name: services id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services ALTER COLUMN id SET DEFAULT nextval('public.services_id_seq'::regclass);


--
-- Name: tenants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants ALTER COLUMN id SET DEFAULT nextval('public.tenants_id_seq'::regclass);


--
-- Name: update_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.update_states ALTER COLUMN id SET DEFAULT nextval('public.update_states_id_seq'::regclass);


--
-- Name: usage_limits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_limits ALTER COLUMN id SET DEFAULT nextval('public.usage_limits_id_seq'::regclass);


--
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: entries entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT entries_pkey PRIMARY KEY (id);


--
-- Name: integration_states integration_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_states
    ADD CONSTRAINT integration_states_pkey PRIMARY KEY (id);


--
-- Name: integrations integrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integrations
    ADD CONSTRAINT integrations_pkey PRIMARY KEY (id);


--
-- Name: message_bus message_bus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_bus
    ADD CONSTRAINT message_bus_pkey PRIMARY KEY (id);


--
-- Name: metrics metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics
    ADD CONSTRAINT metrics_pkey PRIMARY KEY (id);


--
-- Name: models models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.models
    ADD CONSTRAINT models_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: providers providers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.providers
    ADD CONSTRAINT providers_pkey PRIMARY KEY (id);


--
-- Name: proxies proxies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proxies
    ADD CONSTRAINT proxies_pkey PRIMARY KEY (id);


--
-- Name: que_jobs que_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_jobs
    ADD CONSTRAINT que_jobs_pkey PRIMARY KEY (id);


--
-- Name: que_lockers que_lockers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_lockers
    ADD CONSTRAINT que_lockers_pkey PRIMARY KEY (pid);


--
-- Name: que_values que_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_values
    ADD CONSTRAINT que_values_pkey PRIMARY KEY (key);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (id);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: update_states update_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.update_states
    ADD CONSTRAINT update_states_pkey PRIMARY KEY (id);


--
-- Name: usage_limits usage_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_limits
    ADD CONSTRAINT usage_limits_pkey PRIMARY KEY (id);


--
-- Name: index_applications_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applications_on_service_id ON public.applications USING btree (service_id);


--
-- Name: index_applications_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applications_on_tenant_id ON public.applications USING btree (tenant_id);


--
-- Name: index_clients_on_client_id_and_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_client_id_and_service_id ON public.clients USING btree (client_id, service_id);


--
-- Name: index_clients_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_service_id ON public.clients USING btree (service_id);


--
-- Name: index_clients_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_tenant_id ON public.clients USING btree (tenant_id);


--
-- Name: index_entries_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_model_id ON public.entries USING btree (model_id);


--
-- Name: index_entries_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_tenant_id ON public.entries USING btree (tenant_id);


--
-- Name: index_integration_states_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_states_on_entry_id ON public.integration_states USING btree (entry_id);


--
-- Name: index_integration_states_on_integration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_states_on_integration_id ON public.integration_states USING btree (integration_id);


--
-- Name: index_integration_states_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_states_on_model_id ON public.integration_states USING btree (model_id);


--
-- Name: index_integration_states_on_model_id_and_integration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integration_states_on_model_id_and_integration_id ON public.integration_states USING btree (model_id, integration_id);


--
-- Name: index_integrations_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integrations_on_model_id ON public.integrations USING btree (model_id);


--
-- Name: index_integrations_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integrations_on_tenant_id ON public.integrations USING btree (tenant_id);


--
-- Name: index_integrations_on_tenant_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integrations_on_tenant_id_and_type ON public.integrations USING btree (tenant_id, type) WHERE (model_id IS NULL);


--
-- Name: index_integrations_on_tenant_id_and_type_and_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integrations_on_tenant_id_and_type_and_model_id ON public.integrations USING btree (tenant_id, type, model_id) WHERE (model_id IS NOT NULL);


--
-- Name: index_metrics_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_metrics_on_service_id ON public.metrics USING btree (service_id);


--
-- Name: index_metrics_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_metrics_on_tenant_id ON public.metrics USING btree (tenant_id);


--
-- Name: index_models_on_record; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_models_on_record ON public.models USING btree (record_type, record_id);


--
-- Name: index_models_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_models_on_tenant_id ON public.models USING btree (tenant_id);


--
-- Name: index_notifications_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_model_id ON public.notifications USING btree (model_id);


--
-- Name: index_notifications_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_tenant_id ON public.notifications USING btree (tenant_id);


--
-- Name: index_providers_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_providers_on_tenant_id ON public.providers USING btree (tenant_id);


--
-- Name: index_proxies_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proxies_on_service_id ON public.proxies USING btree (service_id);


--
-- Name: index_proxies_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proxies_on_tenant_id ON public.proxies USING btree (tenant_id);


--
-- Name: index_services_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_tenant_id ON public.services USING btree (tenant_id);


--
-- Name: index_update_states_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_update_states_on_model_id ON public.update_states USING btree (model_id);


--
-- Name: index_usage_limits_on_metric_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_limits_on_metric_id ON public.usage_limits USING btree (metric_id);


--
-- Name: index_usage_limits_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_limits_on_tenant_id ON public.usage_limits USING btree (tenant_id);


--
-- Name: que_jobs_args_gin_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX que_jobs_args_gin_idx ON public.que_jobs USING gin (args jsonb_path_ops);


--
-- Name: que_jobs_data_gin_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX que_jobs_data_gin_idx ON public.que_jobs USING gin (data jsonb_path_ops);


--
-- Name: que_poll_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX que_poll_idx ON public.que_jobs USING btree (queue, priority, run_at, id) WHERE ((finished_at IS NULL) AND (expired_at IS NULL));


--
-- Name: que_poll_idx_with_job_schema_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX que_poll_idx_with_job_schema_version ON public.que_jobs USING btree (job_schema_version, queue, priority, run_at, id) WHERE ((finished_at IS NULL) AND (expired_at IS NULL));


--
-- Name: table_added_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX table_added_at_index ON public.message_bus USING btree (added_at);


--
-- Name: table_channel_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX table_channel_id_index ON public.message_bus USING btree (channel, id);


--
-- Name: que_jobs que_job_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER que_job_notify AFTER INSERT ON public.que_jobs FOR EACH ROW EXECUTE PROCEDURE public.que_job_notify();


--
-- Name: que_jobs que_state_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER que_state_notify AFTER INSERT OR DELETE OR UPDATE ON public.que_jobs FOR EACH ROW EXECUTE PROCEDURE public.que_state_notify();


--
-- Name: integration_states fk_rails_1133bc1397; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_states
    ADD CONSTRAINT fk_rails_1133bc1397 FOREIGN KEY (model_id) REFERENCES public.models(id);


--
-- Name: proxies fk_rails_1b8514170a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proxies
    ADD CONSTRAINT fk_rails_1b8514170a FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: usage_limits fk_rails_29f5c8eedd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_limits
    ADD CONSTRAINT fk_rails_29f5c8eedd FOREIGN KEY (metric_id) REFERENCES public.metrics(id);


--
-- Name: notifications fk_rails_3833a979e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_3833a979e0 FOREIGN KEY (model_id) REFERENCES public.models(id);


--
-- Name: entries fk_rails_463bb0a9cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_463bb0a9cc FOREIGN KEY (model_id) REFERENCES public.models(id);


--
-- Name: models fk_rails_47bc1b5b2f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.models
    ADD CONSTRAINT fk_rails_47bc1b5b2f FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: clients fk_rails_4904dbddb8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_4904dbddb8 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: proxies fk_rails_574a99191a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proxies
    ADD CONSTRAINT fk_rails_574a99191a FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: integration_states fk_rails_5f9da38b71; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_states
    ADD CONSTRAINT fk_rails_5f9da38b71 FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: update_states fk_rails_66e50c4ac9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.update_states
    ADD CONSTRAINT fk_rails_66e50c4ac9 FOREIGN KEY (model_id) REFERENCES public.models(id);


--
-- Name: usage_limits fk_rails_7464a81431; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_limits
    ADD CONSTRAINT fk_rails_7464a81431 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: notifications fk_rails_7c99fe0556; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_7c99fe0556 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: clients fk_rails_82a7d45fdb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT fk_rails_82a7d45fdb FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: integration_states fk_rails_9c9a857590; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_states
    ADD CONSTRAINT fk_rails_9c9a857590 FOREIGN KEY (integration_id) REFERENCES public.integrations(id);


--
-- Name: entries fk_rails_acc13c3cee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_acc13c3cee FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: providers fk_rails_ba1a501ef5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.providers
    ADD CONSTRAINT fk_rails_ba1a501ef5 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: applications fk_rails_c363b8b058; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT fk_rails_c363b8b058 FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: metrics fk_rails_c50b7368c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics
    ADD CONSTRAINT fk_rails_c50b7368c1 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: metrics fk_rails_c7fa7e0e14; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics
    ADD CONSTRAINT fk_rails_c7fa7e0e14 FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: services fk_rails_c99dfff855; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT fk_rails_c99dfff855 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: applications fk_rails_cbcddd5826; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT fk_rails_cbcddd5826 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- Name: integrations fk_rails_cd54ced205; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integrations
    ADD CONSTRAINT fk_rails_cd54ced205 FOREIGN KEY (model_id) REFERENCES public.models(id);


--
-- Name: integrations fk_rails_d329ca1b17; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integrations
    ADD CONSTRAINT fk_rails_d329ca1b17 FOREIGN KEY (tenant_id) REFERENCES public.tenants(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20170602105141'),
('20170602105146'),
('20170602112320'),
('20170602115805'),
('20170602120831'),
('20170602120909'),
('20170602122059'),
('20170602142516'),
('20170602162517'),
('20170605112051'),
('20170605112058'),
('20170612073714'),
('20170620114832'),
('20181019101631'),
('20190410112007'),
('20190530080459'),
('20190603140450'),
('20190605094424'),
('20210504152609'),
('20230629131935');


