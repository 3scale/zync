SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE applications (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    service_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: applications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE applications_id_seq OWNED BY applications.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE entries (
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

CREATE SEQUENCE entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE entries_id_seq OWNED BY entries.id;


--
-- Name: integration_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE integration_states (
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

CREATE SEQUENCE integration_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: integration_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE integration_states_id_seq OWNED BY integration_states.id;


--
-- Name: integrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE integrations (
    id bigint NOT NULL,
    configuration jsonb,
    type character varying NOT NULL,
    tenant_id bigint,
    model_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: integrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE integrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: integrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE integrations_id_seq OWNED BY integrations.id;


--
-- Name: metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE metrics (
    id bigint NOT NULL,
    service_id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE metrics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE metrics_id_seq OWNED BY metrics.id;


--
-- Name: models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE models (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    record_type character varying,
    record_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: models_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE models_id_seq OWNED BY models.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE notifications (
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

CREATE SEQUENCE notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notifications_id_seq OWNED BY notifications.id;


--
-- Name: proxies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE proxies (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    service_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: proxies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE proxies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: proxies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE proxies_id_seq OWNED BY proxies.id;


--
-- Name: que_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE que_jobs (
    priority smallint DEFAULT 100 NOT NULL,
    run_at timestamp with time zone DEFAULT now() NOT NULL,
    job_id bigint NOT NULL,
    job_class text NOT NULL,
    args json DEFAULT '[]'::json NOT NULL,
    error_count integer DEFAULT 0 NOT NULL,
    last_error text,
    queue text DEFAULT ''::text NOT NULL
);


--
-- Name: TABLE que_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE que_jobs IS '3';


--
-- Name: que_jobs_job_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE que_jobs_job_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: que_jobs_job_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE que_jobs_job_id_seq OWNED BY que_jobs.job_id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE schema_migrations (
    version character varying NOT NULL
);


--
-- Name: services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE services (
    id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: services_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE services_id_seq OWNED BY services.id;


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE tenants (
    id bigint NOT NULL,
    endpoint character varying NOT NULL,
    access_token character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: tenants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tenants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tenants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tenants_id_seq OWNED BY tenants.id;


--
-- Name: update_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE update_states (
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

CREATE SEQUENCE update_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: update_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE update_states_id_seq OWNED BY update_states.id;


--
-- Name: usage_limits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE usage_limits (
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

CREATE SEQUENCE usage_limits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usage_limits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE usage_limits_id_seq OWNED BY usage_limits.id;


--
-- Name: applications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY applications ALTER COLUMN id SET DEFAULT nextval('applications_id_seq'::regclass);


--
-- Name: entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY entries ALTER COLUMN id SET DEFAULT nextval('entries_id_seq'::regclass);


--
-- Name: integration_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY integration_states ALTER COLUMN id SET DEFAULT nextval('integration_states_id_seq'::regclass);


--
-- Name: integrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY integrations ALTER COLUMN id SET DEFAULT nextval('integrations_id_seq'::regclass);


--
-- Name: metrics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY metrics ALTER COLUMN id SET DEFAULT nextval('metrics_id_seq'::regclass);


--
-- Name: models id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY models ALTER COLUMN id SET DEFAULT nextval('models_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY notifications ALTER COLUMN id SET DEFAULT nextval('notifications_id_seq'::regclass);


--
-- Name: proxies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY proxies ALTER COLUMN id SET DEFAULT nextval('proxies_id_seq'::regclass);


--
-- Name: que_jobs job_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY que_jobs ALTER COLUMN job_id SET DEFAULT nextval('que_jobs_job_id_seq'::regclass);


--
-- Name: services id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY services ALTER COLUMN id SET DEFAULT nextval('services_id_seq'::regclass);


--
-- Name: tenants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY tenants ALTER COLUMN id SET DEFAULT nextval('tenants_id_seq'::regclass);


--
-- Name: update_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY update_states ALTER COLUMN id SET DEFAULT nextval('update_states_id_seq'::regclass);


--
-- Name: usage_limits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY usage_limits ALTER COLUMN id SET DEFAULT nextval('usage_limits_id_seq'::regclass);


--
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: entries entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entries
    ADD CONSTRAINT entries_pkey PRIMARY KEY (id);


--
-- Name: integration_states integration_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY integration_states
    ADD CONSTRAINT integration_states_pkey PRIMARY KEY (id);


--
-- Name: integrations integrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY integrations
    ADD CONSTRAINT integrations_pkey PRIMARY KEY (id);


--
-- Name: metrics metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY metrics
    ADD CONSTRAINT metrics_pkey PRIMARY KEY (id);


--
-- Name: models models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY models
    ADD CONSTRAINT models_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: proxies proxies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY proxies
    ADD CONSTRAINT proxies_pkey PRIMARY KEY (id);


--
-- Name: que_jobs que_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY que_jobs
    ADD CONSTRAINT que_jobs_pkey PRIMARY KEY (queue, priority, run_at, job_id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY services
    ADD CONSTRAINT services_pkey PRIMARY KEY (id);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: update_states update_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY update_states
    ADD CONSTRAINT update_states_pkey PRIMARY KEY (id);


--
-- Name: usage_limits usage_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY usage_limits
    ADD CONSTRAINT usage_limits_pkey PRIMARY KEY (id);


--
-- Name: index_applications_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applications_on_service_id ON applications USING btree (service_id);


--
-- Name: index_applications_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applications_on_tenant_id ON applications USING btree (tenant_id);


--
-- Name: index_entries_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_model_id ON entries USING btree (model_id);


--
-- Name: index_entries_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_tenant_id ON entries USING btree (tenant_id);


--
-- Name: index_integration_states_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_states_on_entry_id ON integration_states USING btree (entry_id);


--
-- Name: index_integration_states_on_integration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_states_on_integration_id ON integration_states USING btree (integration_id);


--
-- Name: index_integration_states_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_states_on_model_id ON integration_states USING btree (model_id);


--
-- Name: index_integration_states_on_model_id_and_integration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integration_states_on_model_id_and_integration_id ON integration_states USING btree (model_id, integration_id);


--
-- Name: index_integrations_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integrations_on_model_id ON integrations USING btree (model_id);


--
-- Name: index_integrations_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integrations_on_tenant_id ON integrations USING btree (tenant_id);


--
-- Name: index_integrations_on_tenant_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integrations_on_tenant_id_and_type ON integrations USING btree (tenant_id, type) WHERE (model_id IS NULL);


--
-- Name: index_integrations_on_tenant_id_and_type_and_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integrations_on_tenant_id_and_type_and_model_id ON integrations USING btree (tenant_id, type, model_id) WHERE (model_id IS NOT NULL);


--
-- Name: index_metrics_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_metrics_on_service_id ON metrics USING btree (service_id);


--
-- Name: index_metrics_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_metrics_on_tenant_id ON metrics USING btree (tenant_id);


--
-- Name: index_models_on_record_type_and_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_models_on_record_type_and_record_id ON models USING btree (record_type, record_id);


--
-- Name: index_models_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_models_on_tenant_id ON models USING btree (tenant_id);


--
-- Name: index_notifications_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_model_id ON notifications USING btree (model_id);


--
-- Name: index_notifications_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_tenant_id ON notifications USING btree (tenant_id);


--
-- Name: index_proxies_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proxies_on_service_id ON proxies USING btree (service_id);


--
-- Name: index_proxies_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_proxies_on_tenant_id ON proxies USING btree (tenant_id);


--
-- Name: index_services_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_tenant_id ON services USING btree (tenant_id);


--
-- Name: index_update_states_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_update_states_on_model_id ON update_states USING btree (model_id);


--
-- Name: index_usage_limits_on_metric_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_limits_on_metric_id ON usage_limits USING btree (metric_id);


--
-- Name: index_usage_limits_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_limits_on_tenant_id ON usage_limits USING btree (tenant_id);


--
-- Name: integration_states fk_rails_1133bc1397; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY integration_states
    ADD CONSTRAINT fk_rails_1133bc1397 FOREIGN KEY (model_id) REFERENCES models(id);


--
-- Name: proxies fk_rails_1b8514170a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY proxies
    ADD CONSTRAINT fk_rails_1b8514170a FOREIGN KEY (service_id) REFERENCES services(id);


--
-- Name: usage_limits fk_rails_29f5c8eedd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY usage_limits
    ADD CONSTRAINT fk_rails_29f5c8eedd FOREIGN KEY (metric_id) REFERENCES metrics(id);


--
-- Name: notifications fk_rails_3833a979e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT fk_rails_3833a979e0 FOREIGN KEY (model_id) REFERENCES models(id);


--
-- Name: entries fk_rails_463bb0a9cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entries
    ADD CONSTRAINT fk_rails_463bb0a9cc FOREIGN KEY (model_id) REFERENCES models(id);


--
-- Name: models fk_rails_47bc1b5b2f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY models
    ADD CONSTRAINT fk_rails_47bc1b5b2f FOREIGN KEY (tenant_id) REFERENCES tenants(id);


--
-- Name: proxies fk_rails_574a99191a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY proxies
    ADD CONSTRAINT fk_rails_574a99191a FOREIGN KEY (tenant_id) REFERENCES tenants(id);


--
-- Name: integration_states fk_rails_5f9da38b71; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY integration_states
    ADD CONSTRAINT fk_rails_5f9da38b71 FOREIGN KEY (entry_id) REFERENCES entries(id);


--
-- Name: update_states fk_rails_66e50c4ac9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY update_states
    ADD CONSTRAINT fk_rails_66e50c4ac9 FOREIGN KEY (model_id) REFERENCES models(id);


--
-- Name: usage_limits fk_rails_7464a81431; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY usage_limits
    ADD CONSTRAINT fk_rails_7464a81431 FOREIGN KEY (tenant_id) REFERENCES tenants(id);


--
-- Name: notifications fk_rails_7c99fe0556; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT fk_rails_7c99fe0556 FOREIGN KEY (tenant_id) REFERENCES tenants(id);


--
-- Name: integration_states fk_rails_9c9a857590; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY integration_states
    ADD CONSTRAINT fk_rails_9c9a857590 FOREIGN KEY (integration_id) REFERENCES integrations(id);


--
-- Name: entries fk_rails_acc13c3cee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY entries
    ADD CONSTRAINT fk_rails_acc13c3cee FOREIGN KEY (tenant_id) REFERENCES tenants(id);


--
-- Name: applications fk_rails_c363b8b058; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY applications
    ADD CONSTRAINT fk_rails_c363b8b058 FOREIGN KEY (service_id) REFERENCES services(id);


--
-- Name: metrics fk_rails_c50b7368c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY metrics
    ADD CONSTRAINT fk_rails_c50b7368c1 FOREIGN KEY (tenant_id) REFERENCES tenants(id);


--
-- Name: metrics fk_rails_c7fa7e0e14; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY metrics
    ADD CONSTRAINT fk_rails_c7fa7e0e14 FOREIGN KEY (service_id) REFERENCES services(id);


--
-- Name: services fk_rails_c99dfff855; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY services
    ADD CONSTRAINT fk_rails_c99dfff855 FOREIGN KEY (tenant_id) REFERENCES tenants(id);


--
-- Name: applications fk_rails_cbcddd5826; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY applications
    ADD CONSTRAINT fk_rails_cbcddd5826 FOREIGN KEY (tenant_id) REFERENCES tenants(id);


--
-- Name: integrations fk_rails_cd54ced205; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY integrations
    ADD CONSTRAINT fk_rails_cd54ced205 FOREIGN KEY (model_id) REFERENCES models(id);


--
-- Name: integrations fk_rails_d329ca1b17; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY integrations
    ADD CONSTRAINT fk_rails_d329ca1b17 FOREIGN KEY (tenant_id) REFERENCES tenants(id);


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
('20170620114832');


