--
-- PostgreSQL database dump
--

\restrict JMclcjkgaWwlG2aCcrZitRaSETAvILCu4ZS3bWShfihoWxzXRaRT6INrDKeq6Iu

-- Dumped from database version 15.17
-- Dumped by pg_dump version 15.17

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admins (
    admin_id character varying NOT NULL,
    auth_user_id uuid NOT NULL,
    name character varying NOT NULL,
    email character varying NOT NULL,
    needs_password_reset boolean NOT NULL,
    phone character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    password_hash character varying
);


--
-- Name: attendance_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance_log (
    id bigint NOT NULL,
    student_id character varying NOT NULL,
    lecture_id character varying NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    status character varying NOT NULL,
    method character varying NOT NULL
);


--
-- Name: attendance_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attendance_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attendance_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attendance_log_id_seq OWNED BY public.attendance_log.id;


--
-- Name: class_schedule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.class_schedule (
    schedule_id character varying NOT NULL,
    class_id character varying NOT NULL,
    day_of_week character varying NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL
);


--
-- Name: classes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classes (
    class_id character varying NOT NULL,
    course_id character varying NOT NULL,
    lecturer_id character varying,
    section_name character varying,
    room character varying,
    semester character varying,
    year integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: courses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courses (
    course_id character varying NOT NULL,
    title character varying NOT NULL,
    department character varying,
    credit_hours integer,
    semester character varying,
    year integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: emotion_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.emotion_log (
    id bigint NOT NULL,
    student_id character varying NOT NULL,
    lecture_id character varying NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    emotion character varying NOT NULL,
    confidence double precision NOT NULL,
    engagement_score double precision NOT NULL
);


--
-- Name: emotion_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.emotion_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: emotion_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.emotion_log_id_seq OWNED BY public.emotion_log.id;


--
-- Name: enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enrollments (
    id bigint NOT NULL,
    class_id character varying NOT NULL,
    student_id character varying NOT NULL,
    enrolled_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: enrollments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enrollments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enrollments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enrollments_id_seq OWNED BY public.enrollments.id;


--
-- Name: exams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exams (
    exam_id character varying NOT NULL,
    class_id character varying NOT NULL,
    lecture_id character varying,
    title character varying NOT NULL,
    scheduled_start timestamp with time zone,
    end_time timestamp with time zone,
    auto_submit boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: focus_strikes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_strikes (
    id bigint NOT NULL,
    student_id character varying NOT NULL,
    lecture_id character varying NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    strike_type character varying NOT NULL
);


--
-- Name: focus_strikes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.focus_strikes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: focus_strikes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.focus_strikes_id_seq OWNED BY public.focus_strikes.id;


--
-- Name: incidents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.incidents (
    id bigint NOT NULL,
    student_id character varying,
    exam_id character varying,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    flag_type character varying NOT NULL,
    severity integer NOT NULL,
    evidence_path character varying
);


--
-- Name: incidents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.incidents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: incidents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.incidents_id_seq OWNED BY public.incidents.id;


--
-- Name: lecturers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lecturers (
    lecturer_id character varying NOT NULL,
    auth_user_id uuid NOT NULL,
    name character varying NOT NULL,
    email character varying NOT NULL,
    needs_password_reset boolean NOT NULL,
    department character varying,
    title character varying,
    phone character varying,
    photo_url character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    password_hash character varying
);


--
-- Name: lectures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lectures (
    lecture_id character varying NOT NULL,
    class_id character varying,
    lecturer_id character varying NOT NULL,
    title character varying,
    session_type character varying DEFAULT 'lecture'::character varying,
    start_time timestamp with time zone,
    end_time timestamp with time zone,
    scheduled_start timestamp with time zone,
    slide_url character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    actual_start_time timestamp with time zone,
    actual_end_time timestamp with time zone,
    total_frames_captured integer DEFAULT 0,
    expected_frames_count integer DEFAULT 0,
    scheduled_end timestamp with time zone
);


--
-- Name: materials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.materials (
    material_id character varying NOT NULL,
    lecture_id character varying NOT NULL,
    lecturer_id character varying NOT NULL,
    title character varying NOT NULL,
    drive_link character varying,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    student_id character varying,
    lecturer_id character varying NOT NULL,
    lecture_id_fk character varying,
    reason character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    read boolean DEFAULT false
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
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.students (
    student_id character varying NOT NULL,
    auth_user_id uuid NOT NULL,
    name character varying NOT NULL,
    email character varying,
    needs_password_reset boolean NOT NULL,
    department character varying,
    year integer,
    face_encoding bytea,
    photo_url character varying,
    enrolled_at timestamp with time zone DEFAULT now() NOT NULL,
    password_hash character varying
);


--
-- Name: attendance_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_log ALTER COLUMN id SET DEFAULT nextval('public.attendance_log_id_seq'::regclass);


--
-- Name: emotion_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emotion_log ALTER COLUMN id SET DEFAULT nextval('public.emotion_log_id_seq'::regclass);


--
-- Name: enrollments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments ALTER COLUMN id SET DEFAULT nextval('public.enrollments_id_seq'::regclass);


--
-- Name: focus_strikes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_strikes ALTER COLUMN id SET DEFAULT nextval('public.focus_strikes_id_seq'::regclass);


--
-- Name: incidents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents ALTER COLUMN id SET DEFAULT nextval('public.incidents_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Data for Name: admins; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.admins (admin_id, auth_user_id, name, email, needs_password_reset, phone, created_at, password_hash) FROM stdin;
MaMohamed_Mohamed _A	8a67ee43-b282-4b6a-91ba-4b5ee9b6f6bd	Mamohamed Mohamed Abdelfattah Abourizka	mamohamed_mohamed _a@aast.edu	t	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
MmMenna_Allah_Maged_	42218e82-2b9c-4fe5-a3b9-df60315e528c	Mmmenna Allah Maged Moustafa Kamel Mohamed	mmmenna_allah_maged_@aast.edu	t	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
WmWael_Abbas_Mahfouz	0820686e-609a-40d4-8a82-1f795833fcc6	Wmwael Abbas Mahfouz Mohamed	wmwael_abbas_mahfouz@aast.edu	t	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
\.


--
-- Data for Name: attendance_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.attendance_log (id, student_id, lecture_id, "timestamp", status, method) FROM stdin;
\.


--
-- Data for Name: class_schedule; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.class_schedule (schedule_id, class_id, day_of_week, start_time, end_time) FROM stdin;
754556ba	1523_1	Monday	12:00:00	16:00:00
353acccc	1523_2	Sunday	08:00:00	15:00:00
033ce6bc	10227_1	Tuesday	13:00:00	17:00:00
9f2b1ba4	10227_2	Thursday	10:00:00	16:00:00
0b2564f6	10230_1	Thursday	10:00:00	17:00:00
66517794	10230_2	Tuesday	09:00:00	16:00:00
d00a0124	10232_1	Tuesday	14:00:00	17:00:00
64e0e42d	10232_2	Tuesday	10:00:00	15:00:00
26064c09	10270_1	Monday	12:00:00	16:00:00
4fab8563	10270_2	Sunday	14:00:00	15:00:00
5156b911	2029_1	Wednesday	13:00:00	16:00:00
e732a48f	2029_2	Thursday	09:00:00	17:00:00
\.


--
-- Data for Name: classes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.classes (class_id, course_id, lecturer_id, section_name, room, semester, year, created_at) FROM stdin;
CLASS_1523	1523	omar	Main Section	\N	Spring	2026	2026-05-10 10:49:59.044702+00
CLASS_10227	10227	omar	Main Section	\N	Spring	2026	2026-05-10 10:49:59.065172+00
CLASS_10230	10230	omar	Main Section	\N	Spring	2026	2026-05-10 10:49:59.095842+00
CLASS_10232	10232	omar	Main Section	\N	Spring	2026	2026-05-10 10:49:59.121881+00
CLASS_10270	10270	omar	Main Section	\N	Spring	2026	2026-05-10 10:49:59.145851+00
CLASS_2029	2029	omar	Main Section	\N	Spring	2026	2026-05-10 10:49:59.168399+00
1523_1	1523	جسجودة_اسماعيل_محمد_	Section 101	Building C - Room 218	Spring	2026	2026-05-10 10:50:00.504144+00
1523_2	1523	AiAlaa_Mahmoud_Sobhy	Section 102	Building A - Room 279	Spring	2026	2026-05-10 10:50:00.504144+00
10227_1	10227	omar	Section 101	Building A - Room 338	Spring	2026	2026-05-10 10:50:00.504144+00
10227_2	10227	ABAhmed_Yehia_Sayed_	Section 102	Building C - Room 121	Spring	2026	2026-05-10 10:50:00.504144+00
10230_1	10230	MaMohamed_Mohib_abde	Section 101	Building C - Room 297	Spring	2026	2026-05-10 10:50:00.504144+00
10230_2	10230	ABAhmed_Yehia_Sayed_	Section 102	Building B - Room 117	Spring	2026	2026-05-10 10:50:00.504144+00
10232_1	10232	ABAhmed_Yehia_Sayed_	Section 101	Building C - Room 231	Spring	2026	2026-05-10 10:50:00.504144+00
10232_2	10232	MaMohamed_Mohib_abde	Section 102	Building C - Room 396	Spring	2026	2026-05-10 10:50:00.504144+00
10270_1	10270	ABAhmed_Yehia_Sayed_	Section 101	Building B - Room 220	Spring	2026	2026-05-10 10:50:00.504144+00
10270_2	10270	omar	Section 102	Building A - Room 137	Spring	2026	2026-05-10 10:50:00.504144+00
2029_1	2029	ABAhmed_Yehia_Sayed_	Section 101	Building A - Room 260	Spring	2026	2026-05-10 10:50:00.504144+00
2029_2	2029	HeHagar_Louye_Elsaye	Section 102	Building B - Room 147	Spring	2026	2026-05-10 10:50:00.504144+00
\.


--
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.courses (course_id, title, department, credit_hours, semester, year, created_at) FROM stdin;
1523	[CCS3002] Numerical Methods - Misr El Gedida	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00
10227	[CCS3003] System Modeling And Simulation - Misr El Gedida	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00
10230	[CCS3403] Computing Algorithms - Misr El Gedida	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00
10232	[CCS3501] Computer Graphics - Misr El Gedida	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00
10270	[CIT3601] Professional Training In Ai I - Misr El Gedida	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00
2029	[EBA3201] Advanced Statistics - Misr El Gedida	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00
\.


--
-- Data for Name: emotion_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.emotion_log (id, student_id, lecture_id, "timestamp", emotion, confidence, engagement_score) FROM stdin;
\.


--
-- Data for Name: enrollments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.enrollments (id, class_id, student_id, enrolled_at) FROM stdin;
1071	10270_2	231006367	2026-05-10 10:50:00.663994+00
1072	1523_1	231006367	2026-05-10 10:50:00.663994+00
1073	1523_1	231015291	2026-05-10 10:50:00.663994+00
1074	10270_2	231015291	2026-05-10 10:50:00.663994+00
1075	10230_2	231015291	2026-05-10 10:50:00.663994+00
1076	1523_1	231014184	2026-05-10 10:50:00.663994+00
1077	2029_2	231014184	2026-05-10 10:50:00.663994+00
1078	10270_1	231014670	2026-05-10 10:50:00.663994+00
1079	10227_2	231014670	2026-05-10 10:50:00.663994+00
1080	2029_1	231014670	2026-05-10 10:50:00.663994+00
1081	1523_1	231006507	2026-05-10 10:50:00.663994+00
1082	10270_1	231006507	2026-05-10 10:50:00.663994+00
1083	1523_2	231006507	2026-05-10 10:50:00.663994+00
1084	10230_1	231005837	2026-05-10 10:50:00.663994+00
1085	10230_2	231005837	2026-05-10 10:50:00.663994+00
1086	1523_2	231005837	2026-05-10 10:50:00.663994+00
1087	2029_1	231006798	2026-05-10 10:50:00.663994+00
1088	10232_1	231006798	2026-05-10 10:50:00.663994+00
1089	10270_2	231004345	2026-05-10 10:50:00.663994+00
1090	1523_2	231004345	2026-05-10 10:50:00.663994+00
1091	10227_2	231004345	2026-05-10 10:50:00.663994+00
1092	10230_2	231014067	2026-05-10 10:50:00.663994+00
1093	10227_1	231014067	2026-05-10 10:50:00.663994+00
1094	2029_2	231005936	2026-05-10 10:50:00.663994+00
1095	10227_1	231005936	2026-05-10 10:50:00.663994+00
1096	10270_2	231005936	2026-05-10 10:50:00.663994+00
1097	2029_2	231004779	2026-05-10 10:50:00.663994+00
1098	10232_1	231004779	2026-05-10 10:50:00.663994+00
1099	1523_2	231014972	2026-05-10 10:50:00.663994+00
1100	10270_1	231014972	2026-05-10 10:50:00.663994+00
1101	10270_2	231014972	2026-05-10 10:50:00.663994+00
1102	10232_2	231006982	2026-05-10 10:50:00.663994+00
1103	10232_1	231006982	2026-05-10 10:50:00.663994+00
1104	1523_1	231006760	2026-05-10 10:50:00.663994+00
1105	2029_1	231006760	2026-05-10 10:50:00.663994+00
1106	10232_1	231005898	2026-05-10 10:50:00.663994+00
1107	10227_2	231005898	2026-05-10 10:50:00.663994+00
1108	1523_1	231005898	2026-05-10 10:50:00.663994+00
1109	10230_2	231005756	2026-05-10 10:50:00.663994+00
1110	10227_2	231005756	2026-05-10 10:50:00.663994+00
1111	10227_1	231005756	2026-05-10 10:50:00.663994+00
1112	10232_1	231006916	2026-05-10 10:50:00.663994+00
1113	10232_2	231006916	2026-05-10 10:50:00.663994+00
1114	2029_2	231006916	2026-05-10 10:50:00.663994+00
1115	2029_2	231006688	2026-05-10 10:50:00.663994+00
1116	10232_1	231006688	2026-05-10 10:50:00.663994+00
1117	10227_2	231006688	2026-05-10 10:50:00.663994+00
1118	2029_2	231006359	2026-05-10 10:50:00.663994+00
1119	10230_2	231006359	2026-05-10 10:50:00.663994+00
1120	10227_1	231006359	2026-05-10 10:50:00.663994+00
1121	10230_2	231004095	2026-05-10 10:50:00.663994+00
1122	10232_1	231004095	2026-05-10 10:50:00.663994+00
1123	10230_2	231005820	2026-05-10 10:50:00.663994+00
1124	10227_2	231005820	2026-05-10 10:50:00.663994+00
1125	10227_1	231006309	2026-05-10 10:50:00.663994+00
1126	10270_2	231006309	2026-05-10 10:50:00.663994+00
1127	1523_1	231006309	2026-05-10 10:50:00.663994+00
1128	1523_2	231006563	2026-05-10 10:50:00.663994+00
1129	2029_1	231006563	2026-05-10 10:50:00.663994+00
1130	10230_2	231002467	2026-05-10 10:50:00.663994+00
1131	1523_1	231002467	2026-05-10 10:50:00.663994+00
1132	10232_1	231002467	2026-05-10 10:50:00.663994+00
1133	10230_1	231007895	2026-05-10 10:50:00.663994+00
1134	10232_2	231007895	2026-05-10 10:50:00.663994+00
1135	10230_2	231014770	2026-05-10 10:50:00.663994+00
1136	10227_2	231014770	2026-05-10 10:50:00.663994+00
1137	10232_1	231014770	2026-05-10 10:50:00.663994+00
1138	10227_1	231015308	2026-05-10 10:50:00.663994+00
1139	10232_2	231015308	2026-05-10 10:50:00.663994+00
1140	10230_2	231004836	2026-05-10 10:50:00.663994+00
1141	2029_2	231004836	2026-05-10 10:50:00.663994+00
1142	2029_1	231005027	2026-05-10 10:50:00.663994+00
1143	1523_2	231005027	2026-05-10 10:50:00.663994+00
1144	10232_1	231014083	2026-05-10 10:50:00.663994+00
1145	2029_1	231014083	2026-05-10 10:50:00.663994+00
1146	10270_2	231014083	2026-05-10 10:50:00.663994+00
1147	10232_2	231004160	2026-05-10 10:50:00.663994+00
1148	1523_2	231004160	2026-05-10 10:50:00.663994+00
1149	10270_2	231014373	2026-05-10 10:50:00.663994+00
1150	10270_1	231014373	2026-05-10 10:50:00.663994+00
1151	10232_1	231014373	2026-05-10 10:50:00.663994+00
1152	2029_2	231006822	2026-05-10 10:50:00.663994+00
1153	10230_1	231006822	2026-05-10 10:50:00.663994+00
1154	10270_2	231006822	2026-05-10 10:50:00.663994+00
1155	10230_1	231006766	2026-05-10 10:50:00.663994+00
1156	10227_2	231006766	2026-05-10 10:50:00.663994+00
1157	10270_2	231014466	2026-05-10 10:50:00.663994+00
1158	10227_1	231014466	2026-05-10 10:50:00.663994+00
1159	10270_1	231006844	2026-05-10 10:50:00.663994+00
1160	10232_1	231006844	2026-05-10 10:50:00.663994+00
1161	1523_2	231006844	2026-05-10 10:50:00.663994+00
1162	1523_1	231004206	2026-05-10 10:50:00.663994+00
1163	10227_2	231004206	2026-05-10 10:50:00.663994+00
1164	1523_2	231006901	2026-05-10 10:50:00.663994+00
1165	10230_1	231006901	2026-05-10 10:50:00.663994+00
1166	10232_1	231006804	2026-05-10 10:50:00.663994+00
1167	10232_2	231006804	2026-05-10 10:50:00.663994+00
1168	10270_2	231006804	2026-05-10 10:50:00.663994+00
1169	2029_1	241004978	2026-05-10 10:50:00.663994+00
1170	10270_2	241004978	2026-05-10 10:50:00.663994+00
1171	1523_1	231014763	2026-05-10 10:50:00.663994+00
1172	10230_2	231014763	2026-05-10 10:50:00.663994+00
1173	10227_1	231014763	2026-05-10 10:50:00.663994+00
1174	1523_1	231005601	2026-05-10 10:50:00.663994+00
1175	10232_2	231005601	2026-05-10 10:50:00.663994+00
1176	10227_1	231005601	2026-05-10 10:50:00.663994+00
1177	10270_1	232004221	2026-05-10 10:50:00.663994+00
1178	10227_1	232004221	2026-05-10 10:50:00.663994+00
1179	1523_2	231006154	2026-05-10 10:50:00.663994+00
1180	1523_1	231006154	2026-05-10 10:50:00.663994+00
1181	10270_2	231006154	2026-05-10 10:50:00.663994+00
1182	2029_1	231004918	2026-05-10 10:50:00.663994+00
1183	10227_1	231004918	2026-05-10 10:50:00.663994+00
1184	10227_2	231004918	2026-05-10 10:50:00.663994+00
1185	1523_1	231005865	2026-05-10 10:50:00.663994+00
1186	10227_1	231005865	2026-05-10 10:50:00.663994+00
1187	10227_2	231005865	2026-05-10 10:50:00.663994+00
1188	2029_1	231014462	2026-05-10 10:50:00.663994+00
1189	10227_1	231014462	2026-05-10 10:50:00.663994+00
1190	10230_1	231014761	2026-05-10 10:50:00.663994+00
1191	2029_1	231014761	2026-05-10 10:50:00.663994+00
1192	10270_2	231014761	2026-05-10 10:50:00.663994+00
1193	10227_2	231006502	2026-05-10 10:50:00.663994+00
1194	1523_1	231006502	2026-05-10 10:50:00.663994+00
1195	10227_1	231006272	2026-05-10 10:50:00.663994+00
1196	10230_1	231006272	2026-05-10 10:50:00.663994+00
1197	1523_2	231006272	2026-05-10 10:50:00.663994+00
1198	1523_2	231004567	2026-05-10 10:50:00.663994+00
1199	10270_2	231004567	2026-05-10 10:50:00.663994+00
1200	10230_2	231004567	2026-05-10 10:50:00.663994+00
1201	10227_2	231005711	2026-05-10 10:50:00.663994+00
1202	10227_1	231005711	2026-05-10 10:50:00.663994+00
1203	10230_1	231005711	2026-05-10 10:50:00.663994+00
1204	10270_1	211014850	2026-05-10 10:50:00.663994+00
1205	10270_2	211014850	2026-05-10 10:50:00.663994+00
1206	2029_1	211014850	2026-05-10 10:50:00.663994+00
1207	10232_1	231006900	2026-05-10 10:50:00.663994+00
1208	10230_2	231006900	2026-05-10 10:50:00.663994+00
1209	10232_2	231014783	2026-05-10 10:50:00.663994+00
1210	10270_1	231014783	2026-05-10 10:50:00.663994+00
1211	10230_1	231014783	2026-05-10 10:50:00.663994+00
1212	10230_1	231005915	2026-05-10 10:50:00.663994+00
1213	10232_2	231005915	2026-05-10 10:50:00.663994+00
1214	10230_2	231014666	2026-05-10 10:50:00.663994+00
1215	1523_2	231014666	2026-05-10 10:50:00.663994+00
1216	10270_1	231014666	2026-05-10 10:50:00.663994+00
1217	10230_2	231006613	2026-05-10 10:50:00.663994+00
1218	1523_1	231006613	2026-05-10 10:50:00.663994+00
1219	10270_1	231017969	2026-05-10 10:50:00.663994+00
1220	10230_2	231017969	2026-05-10 10:50:00.663994+00
1221	2029_1	231017969	2026-05-10 10:50:00.663994+00
1222	2029_2	231006601	2026-05-10 10:50:00.663994+00
1223	10232_1	231006601	2026-05-10 10:50:00.663994+00
1224	1523_1	231006601	2026-05-10 10:50:00.663994+00
1225	10227_1	231006131	2026-05-10 10:50:00.663994+00
1226	1523_2	231006131	2026-05-10 10:50:00.663994+00
1227	10227_1	231015037	2026-05-10 10:50:00.663994+00
1228	10230_2	231015037	2026-05-10 10:50:00.663994+00
1229	10270_2	231015037	2026-05-10 10:50:00.663994+00
1230	2029_2	231014860	2026-05-10 10:50:00.663994+00
1231	2029_1	231014860	2026-05-10 10:50:00.663994+00
1232	10270_2	231014860	2026-05-10 10:50:00.663994+00
1233	10270_1	231008132	2026-05-10 10:50:00.663994+00
1234	1523_1	231008132	2026-05-10 10:50:00.663994+00
1235	2029_1	231004649	2026-05-10 10:50:00.663994+00
1236	2029_2	231004649	2026-05-10 10:50:00.663994+00
1237	10227_1	231015004	2026-05-10 10:50:00.663994+00
1238	10230_1	231015004	2026-05-10 10:50:00.663994+00
1239	10227_1	231004431	2026-05-10 10:50:00.663994+00
1240	10230_1	231004431	2026-05-10 10:50:00.663994+00
1241	1523_2	231014259	2026-05-10 10:50:00.663994+00
1242	10232_2	231014259	2026-05-10 10:50:00.663994+00
1243	2029_2	231014599	2026-05-10 10:50:00.663994+00
1244	1523_1	231014599	2026-05-10 10:50:00.663994+00
1245	10230_2	231014599	2026-05-10 10:50:00.663994+00
1246	10227_1	231006928	2026-05-10 10:50:00.663994+00
1247	10230_2	231006928	2026-05-10 10:50:00.663994+00
1248	10230_1	231006928	2026-05-10 10:50:00.663994+00
1249	2029_1	231006417	2026-05-10 10:50:00.663994+00
1250	1523_1	231006417	2026-05-10 10:50:00.663994+00
1251	10232_1	231014691	2026-05-10 10:50:00.663994+00
1252	1523_2	231014691	2026-05-10 10:50:00.663994+00
1253	10227_1	231014691	2026-05-10 10:50:00.663994+00
1254	1523_1	231014324	2026-05-10 10:50:00.663994+00
1255	1523_2	231014324	2026-05-10 10:50:00.663994+00
1256	2029_1	231006879	2026-05-10 10:50:00.663994+00
1257	10270_2	231006879	2026-05-10 10:50:00.663994+00
1258	1523_1	231006879	2026-05-10 10:50:00.663994+00
1259	10227_1	231005689	2026-05-10 10:50:00.663994+00
1260	1523_2	231005689	2026-05-10 10:50:00.663994+00
1261	10232_2	231005689	2026-05-10 10:50:00.663994+00
1262	10270_2	231005430	2026-05-10 10:50:00.663994+00
1263	10232_2	231005430	2026-05-10 10:50:00.663994+00
1264	10270_1	231004387	2026-05-10 10:50:00.663994+00
1265	10227_2	231004387	2026-05-10 10:50:00.663994+00
1266	10270_2	231004387	2026-05-10 10:50:00.663994+00
1267	10227_2	231004747	2026-05-10 10:50:00.663994+00
1268	10232_1	231004747	2026-05-10 10:50:00.663994+00
1269	10227_1	231004747	2026-05-10 10:50:00.663994+00
1270	10232_2	231006572	2026-05-10 10:50:00.663994+00
1271	10270_1	231006572	2026-05-10 10:50:00.663994+00
1272	10270_2	231004727	2026-05-10 10:50:00.663994+00
1273	10270_1	231004727	2026-05-10 10:50:00.663994+00
1274	10230_2	231004727	2026-05-10 10:50:00.663994+00
1275	10227_2	231005789	2026-05-10 10:50:00.663994+00
1276	2029_2	231005789	2026-05-10 10:50:00.663994+00
1277	10227_1	231005789	2026-05-10 10:50:00.663994+00
1278	2029_2	231014241	2026-05-10 10:50:00.663994+00
1279	10227_2	231014241	2026-05-10 10:50:00.663994+00
1280	1523_2	231004224	2026-05-10 10:50:00.663994+00
1281	10232_2	231004224	2026-05-10 10:50:00.663994+00
1282	2029_1	231014002	2026-05-10 10:50:00.663994+00
1283	10227_1	231014002	2026-05-10 10:50:00.663994+00
1284	1523_1	231014002	2026-05-10 10:50:00.663994+00
1285	2029_2	231014849	2026-05-10 10:50:00.663994+00
1286	10230_1	231014849	2026-05-10 10:50:00.663994+00
1287	10227_2	231014849	2026-05-10 10:50:00.663994+00
1288	2029_2	231014025	2026-05-10 10:50:00.663994+00
1289	10227_1	231014025	2026-05-10 10:50:00.663994+00
1290	2029_1	231014025	2026-05-10 10:50:00.663994+00
1291	10227_2	231014457	2026-05-10 10:50:00.663994+00
1292	10227_1	231014457	2026-05-10 10:50:00.663994+00
1293	2029_1	231014457	2026-05-10 10:50:00.663994+00
1294	10232_1	231006127	2026-05-10 10:50:00.663994+00
1295	10227_2	231006127	2026-05-10 10:50:00.663994+00
1296	10270_2	231004285	2026-05-10 10:50:00.663994+00
1297	10227_2	231004285	2026-05-10 10:50:00.663994+00
1298	10232_2	231005940	2026-05-10 10:50:00.663994+00
1299	2029_2	231005940	2026-05-10 10:50:00.663994+00
1300	10227_2	231005940	2026-05-10 10:50:00.663994+00
1301	2029_1	231014744	2026-05-10 10:50:00.663994+00
1302	10270_1	231014744	2026-05-10 10:50:00.663994+00
1303	10270_2	231014744	2026-05-10 10:50:00.663994+00
1304	10232_1	231006574	2026-05-10 10:50:00.663994+00
1305	2029_2	231006574	2026-05-10 10:50:00.663994+00
1306	1523_2	231006574	2026-05-10 10:50:00.663994+00
1307	10230_1	231006950	2026-05-10 10:50:00.663994+00
1308	10227_1	231006950	2026-05-10 10:50:00.663994+00
1309	10227_1	231014539	2026-05-10 10:50:00.663994+00
1310	10230_1	231014539	2026-05-10 10:50:00.663994+00
1311	10270_2	231014539	2026-05-10 10:50:00.663994+00
1312	10270_2	231005333	2026-05-10 10:50:00.663994+00
1313	10227_2	231005333	2026-05-10 10:50:00.663994+00
1314	10227_1	231005333	2026-05-10 10:50:00.663994+00
1315	10227_2	231005400	2026-05-10 10:50:00.663994+00
1316	1523_1	231005400	2026-05-10 10:50:00.663994+00
1317	10270_2	231014166	2026-05-10 10:50:00.663994+00
1318	10230_2	231014166	2026-05-10 10:50:00.663994+00
1319	10232_1	231014449	2026-05-10 10:50:00.663994+00
1320	10270_2	231014449	2026-05-10 10:50:00.663994+00
1321	10227_1	231006335	2026-05-10 10:50:00.663994+00
1322	10232_1	231006335	2026-05-10 10:50:00.663994+00
1323	10232_1	231006825	2026-05-10 10:50:00.663994+00
1324	2029_2	231006825	2026-05-10 10:50:00.663994+00
1325	1523_1	231014647	2026-05-10 10:50:00.663994+00
1326	10270_1	231014647	2026-05-10 10:50:00.663994+00
1327	10227_2	231014647	2026-05-10 10:50:00.663994+00
1328	10232_1	231004419	2026-05-10 10:50:00.663994+00
1329	1523_2	231004419	2026-05-10 10:50:00.663994+00
1330	10227_2	231004419	2026-05-10 10:50:00.663994+00
1331	10232_1	231015069	2026-05-10 10:50:00.663994+00
1332	2029_2	231015069	2026-05-10 10:50:00.663994+00
1333	1523_1	231015069	2026-05-10 10:50:00.663994+00
1334	2029_2	231006012	2026-05-10 10:50:00.663994+00
1335	10270_2	231006012	2026-05-10 10:50:00.663994+00
1336	2029_2	231014590	2026-05-10 10:50:00.663994+00
1337	10227_2	231014590	2026-05-10 10:50:00.663994+00
1338	2029_2	231006511	2026-05-10 10:50:00.663994+00
1339	10230_2	231006511	2026-05-10 10:50:00.663994+00
1340	10270_2	231006511	2026-05-10 10:50:00.663994+00
1341	10270_2	231006695	2026-05-10 10:50:00.663994+00
1342	10232_1	231006695	2026-05-10 10:50:00.663994+00
1343	10230_1	231014333	2026-05-10 10:50:00.663994+00
1344	1523_2	231014333	2026-05-10 10:50:00.663994+00
1345	10270_1	231014333	2026-05-10 10:50:00.663994+00
1346	10227_1	231016666	2026-05-10 10:50:00.663994+00
1347	10270_1	231016666	2026-05-10 10:50:00.663994+00
1348	10230_1	231006856	2026-05-10 10:50:00.663994+00
1349	10227_1	231006856	2026-05-10 10:50:00.663994+00
1350	10230_2	231006856	2026-05-10 10:50:00.663994+00
1351	10227_1	231014342	2026-05-10 10:50:00.663994+00
1352	10227_2	231014342	2026-05-10 10:50:00.663994+00
1353	10230_1	231014342	2026-05-10 10:50:00.663994+00
1354	10270_1	231005501	2026-05-10 10:50:00.663994+00
1355	10232_1	231005501	2026-05-10 10:50:00.663994+00
1356	1523_2	231015218	2026-05-10 10:50:00.663994+00
1357	10227_1	231015218	2026-05-10 10:50:00.663994+00
1358	10227_1	231004713	2026-05-10 10:50:00.663994+00
1359	10230_1	231004713	2026-05-10 10:50:00.663994+00
1360	10232_2	231014786	2026-05-10 10:50:00.663994+00
1361	10227_1	231014786	2026-05-10 10:50:00.663994+00
1362	2029_1	231014786	2026-05-10 10:50:00.663994+00
1363	10230_1	231005073	2026-05-10 10:50:00.663994+00
1364	2029_1	231005073	2026-05-10 10:50:00.663994+00
1365	10227_2	231005073	2026-05-10 10:50:00.663994+00
1366	2029_1	231014755	2026-05-10 10:50:00.663994+00
1367	10227_2	231014755	2026-05-10 10:50:00.663994+00
1368	10227_2	231006586	2026-05-10 10:50:00.663994+00
1369	10232_1	231006586	2026-05-10 10:50:00.663994+00
1370	10230_1	231006586	2026-05-10 10:50:00.663994+00
1371	10230_2	231014395	2026-05-10 10:50:00.663994+00
1372	10232_2	231014395	2026-05-10 10:50:00.663994+00
1373	2029_1	231014395	2026-05-10 10:50:00.663994+00
1374	CLASS_1523	231006131	2026-05-10 10:50:02.476083+00
1375	CLASS_10227	231006131	2026-05-10 10:50:02.476083+00
1376	CLASS_10230	231006131	2026-05-10 10:50:02.476083+00
1377	CLASS_10232	231006131	2026-05-10 10:50:02.476083+00
1378	CLASS_10270	231006131	2026-05-10 10:50:02.476083+00
1379	CLASS_2029	231006131	2026-05-10 10:50:02.476083+00
1380	10270_2	231006131	2026-05-10 10:50:02.476083+00
\.


--
-- Data for Name: exams; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.exams (exam_id, class_id, lecture_id, title, scheduled_start, end_time, auto_submit, created_at) FROM stdin;
\.


--
-- Data for Name: focus_strikes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.focus_strikes (id, student_id, lecture_id, "timestamp", strike_type) FROM stdin;
\.


--
-- Data for Name: incidents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.incidents (id, student_id, exam_id, "timestamp", flag_type, severity, evidence_path) FROM stdin;
\.


--
-- Data for Name: lecturers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lecturers (lecturer_id, auth_user_id, name, email, needs_password_reset, department, title, phone, photo_url, created_at, password_hash) FROM stdin;
ABAhmed_Yehia_Sayed_	b020a30e-6601-4f4b-910a-59a8b043b484	Abahmed Yehia Sayed Bdr	abahmed_yehia_sayed_@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
AiAlaa_Mahmoud_Sobhy	afb2783f-d46e-42f6-a19f-fc2689f17384	Aialaa Mahmoud Sobhy Ibrahim	aialaa_mahmoud_sobhy@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
EMEhab_Kamel_Mohamed	231abb9c-a4f9-43bb-b702-c5fa718c1b90	Emehab Kamel Mohamed Abousaif	emehab_kamel_mohamed@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
HBHossam_Mohamed_Hes	064ffa0f-f6ff-494c-8a3c-badcb5f9ec1d	Hbhossam Mohamed Hesham Mohamed Mahfouz Badran	hbhossam_mohamed_hes@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
فغفاروق_شعبان_عبد_رب	a0e7a7b1-b968-4d12-b713-21fd03c14542	Fghfrwq Shbn Bd Rbh Ghnym	فغفاروق_شعبان_عبد_رب@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
MaMohamed_Mohib_abde	bbafbd14-0595-47bf-8a94-53a786c1393a	Mamohamed Mohib Abdelsattar	mamohamed_mohib_abde@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
HeHagar_Louye_Elsaye	4a546af3-0cd6-49e8-bf24-bc4832b3e67e	Hehagar Louye Elsayed Mohamed Elghazy	hehagar_louye_elsaye@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
FmFahima_Abdeltawab_	610ee1f4-30c2-4660-ae0a-616d774f4b36	Fmfahima Abdeltawab Maghrabi	fmfahima_abdeltawab_@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
جسجودة_اسماعيل_محمد_	e6d62ee7-e7df-4f9b-bdf0-f1b49e32a8fa	Jsjwdh Smyl Mhmd Slmh	جسجودة_اسماعيل_محمد_@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
خمخالد_مجدى_حنفى_محم	8390a4c1-8c80-40c4-b18a-a25750edf502	Khmkhld Mjda Hnfa Mhmwd	خمخالد_مجدى_حنفى_محم@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
NYNagham_Yehya	e4e9264b-e7c1-4257-8af7-766c4505b318	Nynagham Yehya	nynagham_yehya@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
MeMohamed_Fathy_emam	1b74ac90-0f6d-433a-937c-ee944ef6c0a7	Memohamed Fathy Emam	memohamed_fathy_emam@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
عسعلى_محمد_على_سيد	93594ecb-afd2-4241-9455-4f6e3595a6a7	Sla Mhmd La Syd	عسعلى_محمد_على_سيد@aast.edu	t	\N	\N	\N	\N	2026-05-10 10:49:58.908219+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
omar	231921eb-aff5-4e6a-8f34-2349e3ac4b4e	Omar Metwalli	omarhossammetwally@gmail.com	f	\N	\N	\N	\N	2026-05-10 10:49:59.02377+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
\.


--
-- Data for Name: lectures; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lectures (lecture_id, class_id, lecturer_id, title, session_type, start_time, end_time, scheduled_start, slide_url, created_at, actual_start_time, actual_end_time, total_frames_captured, expected_frames_count, scheduled_end) FROM stdin;
LEC_1523_1	CLASS_1523	omar	Lecture 1: Advanced Numerical Methods - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-09 06:49:59.068275+00	2026-05-09 06:49:59.068275+00	2026-05-09 08:49:59.068275+00	123	0	\N
LEC_1523_2	CLASS_1523	omar	Lecture 2: Advanced Numerical Methods - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-08 09:49:59.074371+00	2026-05-08 09:49:59.074371+00	2026-05-08 11:49:59.074371+00	160	0	\N
LEC_1523_3	CLASS_1523	omar	Lecture 3: Advanced Numerical Methods - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-07 05:49:59.074479+00	2026-05-07 05:49:59.074479+00	2026-05-07 07:49:59.074479+00	62	0	\N
LEC_1523_4	CLASS_1523	omar	Lecture 4: Advanced Numerical Methods - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-06 08:49:59.074556+00	2026-05-06 08:49:59.074556+00	2026-05-06 10:49:59.074556+00	107	0	\N
LEC_1523_5	CLASS_1523	omar	Lecture 5: Advanced Numerical Methods - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-05 04:49:59.074619+00	2026-05-05 04:49:59.074619+00	2026-05-05 06:49:59.074619+00	121	0	\N
LEC_10227_1	CLASS_10227	omar	Lecture 1: Advanced System Modeling And Simulation - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-09 12:49:59.09848+00	2026-05-09 12:49:59.09848+00	2026-05-09 14:49:59.09848+00	102	0	\N
LEC_10227_2	CLASS_10227	omar	Lecture 2: Advanced System Modeling And Simulation - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-08 09:49:59.103494+00	2026-05-08 09:49:59.103494+00	2026-05-08 11:49:59.103494+00	93	0	\N
LEC_10227_3	CLASS_10227	omar	Lecture 3: Advanced System Modeling And Simulation - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-07 08:49:59.103581+00	2026-05-07 08:49:59.103581+00	2026-05-07 10:49:59.103581+00	98	0	\N
LEC_10227_4	CLASS_10227	omar	Lecture 4: Advanced System Modeling And Simulation - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-06 09:49:59.103642+00	2026-05-06 09:49:59.103642+00	2026-05-06 11:49:59.103642+00	95	0	\N
LEC_10227_5	CLASS_10227	omar	Lecture 5: Advanced System Modeling And Simulation - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-05 04:49:59.103722+00	2026-05-05 04:49:59.103722+00	2026-05-05 06:49:59.103722+00	139	0	\N
LEC_10230_1	CLASS_10230	omar	Lecture 1: Advanced Computing Algorithms - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-09 07:49:59.12446+00	2026-05-09 07:49:59.12446+00	2026-05-09 09:49:59.12446+00	92	0	\N
LEC_10230_2	CLASS_10230	omar	Lecture 2: Advanced Computing Algorithms - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-08 10:49:59.129409+00	2026-05-08 10:49:59.129409+00	2026-05-08 12:49:59.129409+00	105	0	\N
LEC_10230_3	CLASS_10230	omar	Lecture 3: Advanced Computing Algorithms - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-07 05:49:59.129497+00	2026-05-07 05:49:59.129497+00	2026-05-07 07:49:59.129497+00	61	0	\N
LEC_10230_4	CLASS_10230	omar	Lecture 4: Advanced Computing Algorithms - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-06 08:49:59.129562+00	2026-05-06 08:49:59.129562+00	2026-05-06 10:49:59.129562+00	56	0	\N
LEC_10230_5	CLASS_10230	omar	Lecture 5: Advanced Computing Algorithms - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-05 06:49:59.12962+00	2026-05-05 06:49:59.12962+00	2026-05-05 08:49:59.12962+00	61	0	\N
LEC_10232_1	CLASS_10232	omar	Lecture 1: Advanced Computer Graphics - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-09 08:49:59.148317+00	2026-05-09 08:49:59.148317+00	2026-05-09 10:49:59.148317+00	55	0	\N
LEC_10232_2	CLASS_10232	omar	Lecture 2: Advanced Computer Graphics - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-08 04:49:59.152892+00	2026-05-08 04:49:59.152892+00	2026-05-08 06:49:59.152892+00	90	0	\N
LEC_10232_3	CLASS_10232	omar	Lecture 3: Advanced Computer Graphics - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-07 08:49:59.152979+00	2026-05-07 08:49:59.152979+00	2026-05-07 10:49:59.152979+00	116	0	\N
LEC_10232_4	CLASS_10232	omar	Lecture 4: Advanced Computer Graphics - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-06 12:49:59.153043+00	2026-05-06 12:49:59.153043+00	2026-05-06 14:49:59.153043+00	106	0	\N
LEC_10232_5	CLASS_10232	omar	Lecture 5: Advanced Computer Graphics - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-05 03:49:59.153103+00	2026-05-05 03:49:59.153103+00	2026-05-05 05:49:59.153103+00	88	0	\N
LEC_10270_1	CLASS_10270	omar	Lecture 1: Advanced Professional Training In Ai I - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-09 06:49:59.170769+00	2026-05-09 06:49:59.170769+00	2026-05-09 08:49:59.170769+00	172	0	\N
LEC_10270_2	CLASS_10270	omar	Lecture 2: Advanced Professional Training In Ai I - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-08 08:49:59.175417+00	2026-05-08 08:49:59.175417+00	2026-05-08 10:49:59.175417+00	114	0	\N
LEC_10270_3	CLASS_10270	omar	Lecture 3: Advanced Professional Training In Ai I - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-07 04:49:59.175512+00	2026-05-07 04:49:59.175512+00	2026-05-07 06:49:59.175512+00	78	0	\N
LEC_10270_4	CLASS_10270	omar	Lecture 4: Advanced Professional Training In Ai I - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-06 12:49:59.175585+00	2026-05-06 12:49:59.175585+00	2026-05-06 14:49:59.175585+00	170	0	\N
LEC_10270_5	CLASS_10270	omar	Lecture 5: Advanced Professional Training In Ai I - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-05 09:49:59.175647+00	2026-05-05 09:49:59.175647+00	2026-05-05 11:49:59.175647+00	126	0	\N
LEC_2029_1	CLASS_2029	omar	Lecture 1: Advanced Advanced Statistics - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-09 10:49:59.192801+00	2026-05-09 10:49:59.192801+00	2026-05-09 12:49:59.192801+00	154	0	\N
LEC_2029_2	CLASS_2029	omar	Lecture 2: Advanced Advanced Statistics - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-08 07:49:59.196804+00	2026-05-08 07:49:59.196804+00	2026-05-08 09:49:59.196804+00	188	0	\N
LEC_2029_3	CLASS_2029	omar	Lecture 3: Advanced Advanced Statistics - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-07 10:49:59.196895+00	2026-05-07 10:49:59.196895+00	2026-05-07 12:49:59.196895+00	198	0	\N
LEC_2029_4	CLASS_2029	omar	Lecture 4: Advanced Advanced Statistics - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-06 11:49:59.196959+00	2026-05-06 11:49:59.196959+00	2026-05-06 13:49:59.196959+00	160	0	\N
LEC_2029_5	CLASS_2029	omar	Lecture 5: Advanced Advanced Statistics - Misr El Gedida	lecture	\N	\N	\N	\N	2026-05-05 06:49:59.197027+00	2026-05-05 06:49:59.197027+00	2026-05-05 08:49:59.197027+00	88	0	\N
LECT_1523_1	1523_1	جسجودة_اسماعيل_محمد_	Archive: 1523_1 Orientation	lecture	\N	2026-05-10 13:50:00.620417+00	\N	\N	2026-05-10 10:50:00.577623+00	\N	\N	0	0	\N
LECT_1523_2	1523_2	AiAlaa_Mahmoud_Sobhy	Archive: 1523_2 Orientation	lecture	\N	2026-05-10 13:50:00.635104+00	\N	\N	2026-05-10 10:50:00.577623+00	\N	\N	0	0	\N
LECT_10227_1	10227_1	omar	Archive: 10227_1 Orientation	lecture	\N	2026-05-10 13:50:00.647543+00	\N	\N	2026-05-10 10:50:00.577623+00	\N	\N	0	0	\N
\.


--
-- Data for Name: materials; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.materials (material_id, lecture_id, lecturer_id, title, drive_link, uploaded_at) FROM stdin;
b4e770f7	LECT_1523_1	جسجودة_اسماعيل_محمد_	Homework 1	https://docs.google.com/presentation/d/1_example	2026-05-10 10:50:00.577623+00
33b39342	LECT_1523_1	جسجودة_اسماعيل_محمد_	Reading List	https://docs.google.com/presentation/d/1_example	2026-05-10 10:50:00.577623+00
ff98d9c8	LECT_1523_2	AiAlaa_Mahmoud_Sobhy	Homework 1	https://docs.google.com/presentation/d/1_example	2026-05-10 10:50:00.577623+00
053512b7	LECT_1523_2	AiAlaa_Mahmoud_Sobhy	Reading List	https://docs.google.com/presentation/d/1_example	2026-05-10 10:50:00.577623+00
c7e698df	LECT_10227_1	omar	Weekly Notes	https://docs.google.com/presentation/d/1_example	2026-05-10 10:50:00.577623+00
a9d1534d	LECT_10227_1	omar	Weekly Notes	https://docs.google.com/presentation/d/1_example	2026-05-10 10:50:00.577623+00
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notifications (id, student_id, lecturer_id, lecture_id_fk, reason, created_at, read) FROM stdin;
\.


--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.students (student_id, auth_user_id, name, email, needs_password_reset, department, year, face_encoding, photo_url, enrolled_at, password_hash) FROM stdin;
231006367	f81e6b96-ad11-4af2-a9cc-1a3620a5dadf	Mhmd L Ltfa	m231006367@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1_niharFKW2_nScrP1uE-Rzz_c_ees93v	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004918	e8b13c58-72cd-4940-83d7-46663c541cb9	Mhmd Slm La	m231004918@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=132572vZqeac-rtmLi_9zRM2WyeB8r6Tu	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005865	444fc21e-3eb5-4a91-9dc3-6d6936b42308	Dha Ymn Hsn	d231005865@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1vhf6R2HHjT0CTC-bTUq8qgYfKtW5f0RN	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005711	8fff3816-481b-432a-ad26-3c759395e8fb	Bsl Smh Slymn	b231005711@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=19jAfV8ZjwsKLGZBBL_FDhtLAJkJlS8hB	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231015291	877baef8-5d43-4552-a54b-3f7866379bc9	Byshwa Mrqs Hbyb	b231015291@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=172CrGR6FqwjD4NeLm5NNbjVMChtYDa1L	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014184	74aff69b-b34c-46f7-812b-38df246ea55f	Mrm Tmr Bdlha	m231014184@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1THJ5C5L6PIKRB7eGjBxHlxWn1167KFBH	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014670	57a800b5-1ed7-4b46-b89c-667bcb18dbcc	Rdwa Shryf Hmd	r231014670@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1We2kGOKYeBLio8UAPhwSuJPhpQq2lFKK	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006507	c5209c3c-774d-4de0-b2eb-c940cef2e021	Nda Shryf Brhym	n231006507@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1Yhd5I0znA7zsOgjVVLdPWB8uIIABFInD	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005837	5fa7873b-9d49-4534-9ba9-2533b82135b6	Mrym Wil Lbwrsla	m231005837@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=174uoXH146c0V__VmuTJMO5dRbe5UfANj	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006798	2f173841-86ee-482a-ba2d-3c36165707d1	Hsyn Hshm Fryd	h231006798@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=19or9fAszo6z1ySC1jH1_WHFIhujbYhuk	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004345	5342c1a9-fd70-443e-983e-de237d21215f	Frh Ysr Brhym	f231004345@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=16Lmu_aYKHbwMwkAFoS--JeG5gD0-Hgj0	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014457	c5093224-1601-414b-be4c-05bdf6274035	Zyd Mhmd Mkhlwf	z231014457@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1C0jaBCQhYE5WtbPOTlIrk1Q5ZN5rk0Iv	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014067	db3f8083-137e-4d37-8c4a-129d01b19f76	Zynh Mhmd Brhym	z231014067@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1Z8pteqpVBeWU8eGV3WJ3Ck-3S2Mds4AF	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005936	762edf44-2e0e-4118-8d68-250fd6695f1e	Mrym Mhmd Slm	m231005936@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1Cs1clYYgA-wXqbktlsQmMjDfXavYpE_n	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004779	447db9d0-f9d6-468d-9cbf-db053c9a3870	Mryw Rft Yd	m231004779@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1CrBIxjj2OQJik1mRw2Ph0-5IUfN4UDxh	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014972	cd7b6d0d-db43-422f-b343-5f336e80f8c5	Br Ymn Bdldhym	b231014972@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1TiBOoYQQXD_utE4k3QlFazWJmQY1U54N	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006982	0e4293e8-fa59-4f8e-8cbf-627c3f304b13	Nda Mhmd Brhym	n231006982@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1TM2-4godFdfauuoWe0ba6NZUXSOPILYh	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006760	6bf897f7-b8b7-4d81-8126-a160c75643ec	Nwr Rd Bwlkhyr	n231006760@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1S5su5yVw5UGv2EJYgKJ4oiWoV7oS6tfG	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005898	e522a205-996a-4bbb-bdea-1e39164561ef	Mdh Wil Slm	m231005898@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=14z0CZPr2u6ncjsXzNcH2a89U4GjkuqGT	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005756	4f408210-c4bc-49ab-a6d7-e6bc2e5d3ff5	Shhd Smh Swd	s231005756@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1iwvEvXtXs4VIE5X_qRa74wExtzIYUn-9	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006916	a8dad952-dc93-4aa5-b175-5945937504a2	Bdllh Khld Mr	b231006916@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1jrp6KFZn9H6oW7EaqbBxMpHE7q4DH27F	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006688	c4900641-76ce-4884-85d0-571bbcd2964b	Bll Shrf Hsn	b231006688@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1h5SKQuxWzzpy4kWZ6A2EZkHdGXxy17W6	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006359	fbc907b4-f910-4b51-9831-50d38f35918d	Ns Mstfa Mkwa	n231006359@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=19MfSA-QcdBy9V9083ncTq1kTzRHC7C5O	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004095	0ffa63b4-5b6e-4620-a327-c05e5b89a2bc	Jwn Mjd Lbyb	j231004095@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1g687tpuzFq9SnP_ar4zSHBWcxzOif9kz	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005820	8abc0064-9c0c-4b89-8076-f88311c28b14	Mr Khld Ywsf	m231005820@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1jUDQMQI0PcTpCNkocFsNy8uZo1Kkn47N	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006309	71fc9e33-2a8a-4b15-8268-f12f6a8d7922	Rwa Yhya Slmh	r231006309@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1i_VBqtd_QVO97KdGje6vybvRN8RKtlF9	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006563	d601f58d-4c99-4918-9ef7-f83edefffb81	Mhmwd Mrw Hmd	m231006563@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1tKb-0QLlDg50GM3LsD8ku0pzsGkODau2	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231002467	74ddd6c5-cf05-45a0-8402-5a0866f5baa4	Shyryn Hmd Hsnyn	s231002467@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1hHhvLnqdeaoSfi-D4KSrC5slhIg1pXF0	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231007895	d1fe8579-6314-4ee2-ad9a-c52cf376c829	Nrymn Dl Lzhra	n231007895@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1UenQOhilne4HoTmktKh32ZvKFSJYhk0u	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014770	f6ffc89b-40e8-4668-ab79-725caef97c46	Frydh Hmd Slym	f231014770@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1CIYUg9GdkWFdgODXBBc01Lv6Q6uky6OD	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231015308	7b5f9738-a78c-4c2a-97ef-70555f746f9c	Mr Shryf Ldhm	m231015308@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1ktAKeBoetytE12mzUnYJKX6bDjdAamPZ	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004836	f60eaf70-28c6-4750-ad2b-077c1559f9cf	Lua Wlyd Bwlmta	l231004836@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1FqWJ80AmVL0N8fOB8jGBooJYy3wt2ePX	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005027	d9af6310-684f-435a-9d40-509da655c7fd	Myr Tf Slh	m231005027@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1qnWOzCoAQzYNEyIJs3qrn3KL-sNdXr7V	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014083	6fc8c2de-346c-4211-87ce-7c01f31b59ed	Hn Yhb La	h231014083@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=15gPRY59bGm-AwiKXuAPsCAnaX6uqXKZD	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004160	53f039e9-5500-4281-bbba-3058e5689c18	Bdllh Mhmd Shtt	b231004160@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1yiBcdXA4_0NqgiMxVJcg73k2N1n96wJP	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014373	a54c14eb-e721-400b-b2b8-7da79a786296	Mhmwd Hmd Shlba	m231014373@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1wtKy8kWddf_ltHY8XRbuNmXdYRjWZF5h	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006822	5ddc0a99-dc37-441b-91bd-6f949d883607	Bdllh Md Hsn	b231006822@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=18V66RsEXNopzZ1YD3UG8f3xMSI-eOolT	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006766	b8c98dcc-d5f0-4adb-a294-84d13c6ded24	Zyd Lsyd Hsn	z231006766@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1ywGOQJi4h9VIC5GuWMEdDvZukzWQ5u8l	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014466	6ae2f500-628e-4633-af06-16af43fea4a0	Rwn Trq Bwldhb	r231014466@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1E5vWG6xIB2oyvUfwVQn1qLW1cVmKA00b	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006844	74f2c9ed-daad-412d-8ef0-a73c1aa097d0	Dhm Hna Smyl	d231006844@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1xBHAJLbVaX4es5vMcnMiZAeyP-4QVMwu	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004206	bf4ec4b8-e817-4c5a-8bd2-090663be732f	Rym Hsyn Hsn	r231004206@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1unWVDOr0wJTfkq3Mg7VoZHIjfY--UkgZ	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006901	1c57ee09-77cb-445b-b456-bd7730797403	Zyd Khld Hmd	z231006901@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1FkfGeaQQiSi9Bg2R2VeS-QYxERmPbZaw	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006804	bd8d0a35-d444-4fd4-b0a7-ca3c2aeb831f	Mrk Hna Bdyr	m231006804@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1gnfJrEcXWSEJWOYr-p3zBV7_uWP9QqoO	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
241004978	24d2fd33-06fd-40e9-b49d-55aac0ddb085	Mr L Lsndyda	m241004978@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1-S2ShiZvZgnE2kci6bcm5ANWZWjAznVL	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014763	57262ff6-46cf-4dff-9343-3f6d0d88e1c7	Ywstyn Mmdwh Myn	y231014763@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1pULdhkTk-4ulCVlGjl4f9Y3AgZ546xtM	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005601	4983a7f1-7226-4e19-8f9c-7759ea07fc05	Ml Ywsf Slh	m231005601@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=17xJqO0_bbqwtuffNx8rbsUEXCzq9FGjA	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
232004221	eea0bb69-aa25-4483-9b5b-21a2abc10af2	Sm Dl Bywma	s232004221@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1kvcZGEfgl0PCJC0WcHZ4yCnMieHdZh5z	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006154	710aabc4-fb1e-45dc-ad1b-5c3072203114	Lynd Hmd Msylha	l231006154@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1l8NSWaNIOcv-eWrcbKPMxMGT0kO-yXdH	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014462	6fe159d8-491b-438b-96a6-0d319b86f2ac	Tsnym Hmd Lwzyr	t231014462@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1IfFJHHqRsbmN7p9AJqzGzVH2XDuo23D0	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014761	7e89186b-184e-4956-bed6-686a637f7e50	Hmsh Shrf Lskhy	h231014761@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1uTLd4ZFCodClny4Puv3AdEvC9-N6W4yN	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006502	27d0a530-a487-457b-89a5-476748d69e1d	Bsmlh Mhmd Mhmd	b231006502@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1XfK82h5IeVGtIIYv3HSI6thWsfwji2VS	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006272	6500a4a1-c763-4820-b666-22d25d92e319	Hmd Khwrshyd Myhwb	h231006272@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1RlqC498EPnvwF3RJt8EgQ1DlULaVoKdo	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004567	13ee8171-14d0-42e2-93d7-b74d1ce7d338	Ysyn Shryf Ljwhry	y231004567@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1boX7QGfoXcRHt0v2xt7QHLcSgYQk09ev	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
211014850	d618204c-c7d0-4cfb-a768-17eff475bbd8	Mrwn Mhmd Khlf	m211014850@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1UyqDWtCMKyGRu5K3GP74bVD2zqavVXOl	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006900	19277170-227e-4237-9597-2a40e194c3de	Llwr Sdq Hsyn	l231006900@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1BBjubX9QacnSD2tg8WeZh_JYmMGgm18f	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014783	aa78365a-d9ef-4c59-accb-03b3bf68863a	Mnh Llh Tyh	m231014783@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1q7DGmpfxD-DZX67adQ7hH5B0jVi27dW9	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005915	d8ba2c13-46ab-4313-97f7-8f567f8ff852	Hmd Fwza Lysrja	h231005915@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1FM5hyT-5nbQjVWHuBL35zt7UK0z_09BA	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014666	db5504b3-b3c4-4380-92bc-caa7a3c4a012	Nwr Hmd Mhmd	n231014666@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1KC1Xgnut0m04fHW4QB95yNF-_ZFm3_vn	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006613	5f4cb74d-8bae-41af-86eb-e6e25f563cb4	Jna Mhmd Ryd	j231006613@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=18efGeWrYdJ61U4FjGACYjWywb-mYi82Y	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231017969	44425521-4189-4ed3-a9c5-072f57d3e10c	Nja La Th	n231017969@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1-2tyU4xLIt676bIWAGb7BOPToKY9kESd	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006601	dfc70d7e-af80-4405-a6d0-12dfd0bedd99	Nwrlhda Shrf Mhmwd	n231006601@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=11PK08htS34vXmbGmBaNyh51UKxVAb7cy	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006131	69c9b5ce-4702-4e18-8c24-9186782a5f17	Mr Hsm Jd	m231006131@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1t9nEVT0EuejALfxZ-UOSqzUvNYHCCSnM	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231015037	94e71200-0781-4b6c-aece-40b61d5fd11f	Sr Mrw Slmh	s231015037@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1GyEqA9umpnGlx25_kujUQ4WUbOt5Iqz2	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014860	f79f895e-9c2a-47a3-a44f-6f18afacb2e0	Rn Ysr Fyfy	r231014860@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1RnXvXlvVx2hZNQAKdIx8lSoSjfSb4xyq	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231008132	9a51c76f-0dc9-41e1-b384-6ec7e05ca36b	Mrwn Bdlmnm Bdlmnm	m231008132@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1aBkw0-Sf3IIgcNqGbobtvV6NVQRBLvzW	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004649	8cc3dffc-65d9-49e5-b270-90b6f662ffb0	La Syd Hsnyn	l231004649@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=13E9nxwWWhwNLt9pv16wYL6xpDfgRkX8u	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231015004	ba8c3a6a-bed4-486d-a7aa-ed7afa6467eb	Mhmd Hmd Lthma	m231015004@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1ES0x7lU6v5s0aH_cAvphwR_M--TkoUWP	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004431	1d70257e-b21b-44cd-8051-eb0530cd49c5	Ysyn Wfyq Twln	y231004431@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1ZQzppXgq3ndp12Ucuxz_2BshX-ExeOPP	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014259	817a2e6f-2a7a-4efe-bcab-75cf3a7d063f	Mhb Myn Hjza	m231014259@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1JeGC5YetKo1NLqqiajkVnENhj4TQS7EK	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014599	fbc667c3-4931-499e-974d-907981cd5279	Ywsf Hmd Lswf	y231014599@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1k6jZXYrmOj2lambJfZFMy9hkV7F9cUCJ	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006928	0b1d0c4c-be32-44e0-ac62-72d482390d08	Krym Mhmd Ftyh	k231006928@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1cguXwO__QRVZuSRYIMboljxi8UeXmQ85	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006417	378c459c-1ea1-435d-a629-760a83fb40f2	Mrwn Mhmd Lshma	m231006417@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=11X-gLO4a7Jd_S155VU8AHQdEOqvN9utK	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014691	fe47a1d6-42db-432a-852e-9be73409bc54	Zyd Yhb Hmd	z231014691@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1j2loeiDcZtjdTPMBv4yUMyRttfmHO2qT	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014324	08fd4420-dcd2-429d-a441-17ede11f277f	Ndym Kml Kml	n231014324@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1K-4VcgfKWke-EZIEzN0tiPFn-9KIAxRD	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006879	1b99fce1-c4d7-4da2-bb72-07cfb2e216f9	Ysyn Tmr Bdlhmyd	y231006879@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1xLPC_8hgx0_byHL44_c4YXcsL5vgFI7M	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005689	9cd3cc24-70ee-4fa4-9d26-82514a898f9f	Rytj La La	r231005689@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1PhMRgPjkz2IyEdQwMWKc3cmka2iR0p5n	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005430	a7ab80df-7682-47ff-a246-c9195584be44	Mhnd Wlyd Nsr	m231005430@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1jExHIJEcCiVLJ9Y4DfvA5yYWO8pXqr7r	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004387	c135c7fc-f528-47b5-b2dc-854f1d799d23	Ywsf Hsyn Nwr	y231004387@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1OsvNlTiqZr6a0VqCBudYu32G39zkfBCq	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004747	ccdacc73-a108-4756-853e-3c4eed600d11	Jyd Mjda Lkhshb	j231004747@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1mRm7Dj3Ozty86PNWtC4Ya1ua_vRwemPG	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006572	f8faaa7c-4748-4f33-a7cc-5f9634bd9525	Zyd Mhmd Hmm	z231006572@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1JoS2Pd4H2XOE4ZRBhh6Hx_PGVJtJMfw-	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004727	717b26f3-1c24-4fb0-a23b-c630c8269caf	Mrwn Wlyd Hjj	m231004727@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1DZrD8guFreVS4t-am_hsf59pMx7Yq8by	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005789	fb1df777-f357-40eb-9f05-9f6466629425	Rwn Tf Hsn	r231005789@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=19Fl3g6XhtCy8T7EPK4DQDJrcNKIk-m73	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014241	dad88297-4382-4707-b3d0-8ce506d15c57	Mstfa Wlyd Lkhwly	m231014241@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1CIgH622qqnFO83Wl1hHiizwAJlAIdw3r	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004224	25ad1258-003c-4e6a-88c2-8ab62dbdade6	Mr Nsht La	m231004224@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1QxqJY2GmxR2nep_u3qEGrXRPDVXuAqCc	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014002	4c86c003-97e2-43fc-8e54-296779978358	Sm Syd Slymn	s231014002@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1GCVdj2ukCVt2Q_F2DrZZSRVj7MT2pDve	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014849	9eb8c675-b066-4386-b4d6-d4c989ba21bc	Dyfyd Tf Mkryws	d231014849@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1sixqXXeDy6S8EGMq1_DGEf8215kPYSjA	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014025	1c1b3a45-f30d-44c2-973e-271552c010d5	Nda Bdlzyz Mnh	n231014025@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1reEUrIekhARfDORmjpcAc0VMpJ90UfJI	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006127	fb8b674f-0af8-409d-ad61-160c20820f76	Myrn Bdldhym Mstfa	m231006127@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1eE28TodJeI0FQAZHdEJSOtcOmumILyqs	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004285	ee4d5687-1a09-4d99-a65c-7dc7c9252978	Bdllh Shrf Bdlzyz	b231004285@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=19hZ73pHzEumJIabMm5b0XFBTEJN_lbPG	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005940	5c3fcda9-b298-49be-88cb-45e250b643ff	Mstfa Mhmd Jbr	m231005940@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=16ObATtzBbDORnmcjk_SPjaMrb5yLCx3u	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014744	c35deede-4271-498b-b125-09b88471c5e6	Mhmd Hmd Mrsy	m231014744@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=13EFTNkfTA4vEFshZD2TgHvcazgKD8yPb	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006574	37e60373-a3c8-47c2-9381-f0cf32f7029c	Lyl Hmd Mwsa	l231006574@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1932IM9EgQ4BUZe4nMdyXu8K_2S40nfEv	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006950	fedba16f-e548-426a-8e3f-25d2d6f8dba4	Ywsf Mhmd Nhlh	y231006950@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1c4sgOVARFz3OJWJLXZDkm4kWkQjHevKv	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014539	73774085-bdee-493b-b36b-e19986f90def	Ysyn Lsyd Lhda	y231014539@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1cbfvYFbeh3gWKbdI5czxpcWiNBjPICd2	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005333	629600fa-8a4d-47e9-87ef-8d50b9cb68ce	Dha Mhmwd Dyf	d231005333@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1ZdLWeqmYjE65_lL0BebKTdMtUoWfdASe	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005400	75bf1af8-a631-4c32-a929-1871c5ffa4a2	Shhd Mhmd Jbryl	s231005400@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1pmZLPTUlCrP8p2W6xyI343E2JG52WYJg	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014166	dcb9e590-ebb5-43ed-bdc5-eda2603a72e7	Nwr Hmd Ljnda	n231014166@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1LAHxo_RwZj3TZmlv_jaolPBwflzUMLS6	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014449	6920bc42-dc06-4e8b-b57f-4ee13d4aa886	Ywsf Krym Mhmd	y231014449@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=19V8Wq9l5Y758aft7La664YM1TDZ2G45t	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006335	23657f50-0047-4a39-8a62-0fe773d9ac16	Mhmd Ysr Frj	m231006335@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1quNROw-4csjvyvPRsa_Rnj4Apqi7KCSM	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006825	cedbda65-3b2f-4d52-b553-c4d58c10e7b4	Ns Mhmd Styt	n231006825@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1UcgVefaii-tcME5AA6IAf0qIJAAf28va	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014647	41c6dd18-e85e-4a89-819c-1d284b13d16f	Bdlrhmn Syd Twfyq	b231014647@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1a_0YxRbDQ4Cnk_fgXRC_Z9h14tc09qnW	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004419	2364a821-8e40-4d7a-8047-b3f0cd25dd8c	Nwr Khld Khlyf	n231004419@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1ePZayqbgEYt56dyEerd-sbttN6ak2hyU	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231015069	3c7aa5ba-e1d2-430f-893f-03b722655614	Srh Rif Bdlslm	s231015069@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1lzy50Z5FG8SAZz8FfXGoiNGBbCxGOUdy	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006012	8264bb85-8c17-4ed4-9bfd-09e081926c18	Hzm Smh Hjj	h231006012@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1u7AgwKZpDr_pPVKRQlzrWmt2au-LiraR	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014590	afaf3457-cdf6-494f-9ade-acaae621cfed	Ywsf Bdlmnm Slmn	y231014590@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1volYaMLDiZ511pPmSpdzuqfx6xbY6grk	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006511	e7c31412-7a1b-4961-bb28-fa1e76176e33	Zyd Mhmd Hmd	z231006511@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1bllpxDsnrSGG0LBprzNtkLnI0R_Tidlw	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006695	3704e5cb-6a7f-4e6e-bbad-a0c6342580a4	Mr Md Lhbsha	m231006695@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1qrWZA_HCqFBgXZTif5L1dSka4_MG8iUC	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014333	ed735147-b4f5-4a50-b3bb-2ecf70a51008	Bdlrhmn Trq Nwr	b231014333@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=18Ucq-myMFpw48ieZkWVvy8otZqAwCEw9	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231016666	4f48c752-fadb-409d-a4d2-eb2b6aa9bec7	Mlk Hmd Brhym	m231016666@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1SUfi5njCSvDTUuydZTwofvja6mR49uo4	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006856	2a8fa372-dab4-4169-a1cf-a21faa3264bb	Ywsf Mhmd Brhym	y231006856@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1FGiGJQHGGyUEvciEYe27rjqyq2V4GsBn	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014342	1872f452-4201-41b5-803f-cf8b4c2554f6	Ftmh Khlyl Khlyl	f231014342@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1Ml1qjCdm2GZ8v_pCuJbdPt2puiWUUfH0	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005501	13a2bf76-06eb-4c39-94c3-fc377a8ea1e9	Nnsa Mhmd Rft	n231005501@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1d7vwkmxYKmEhHlmPvpV-qKgTG9xMcvA4	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231015218	64f621fe-f990-4fe6-b1b5-afbc4ee6b220	Bdlrhmn Mhmd Bdlnba	b231015218@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1DpW0I6_wOfGU4fd7dz__PX_RUot_go8i	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231004713	8819092b-4b56-4ee8-9cde-dba1d2b70fc4	Yhya Hmd Lhwa	y231004713@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1lFmcC68a48dtCOkvbHnOs0ly6QhpXbJP	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014786	c96d17ca-251d-43b8-ac59-5ddd04a0817a	Hmd Mhmd Mhmd	h231014786@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1SoqrtK-440MJbsGSWppYa7haAyYjHh50	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231005073	d1d1ddee-23dd-4361-9fc2-67380149b0e6	Bdlrhmn Mhmd Lswa	b231005073@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1KszOqwWU1GH7keQVA4ikyuVriDbxXt4R	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014755	b0439d6f-5eb6-4b88-a839-3c476fec8aad	Bdlrhmn Hmd Lywh	b231014755@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1Gs19IhlnDYTJEMuVyJFgd7KumyDHy4MP	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231006586	01d5f5f6-cb38-4acb-8a11-1b8fa362883b	Rqyh Hmda Rbh	r231006586@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=17o3s6GiZsBgSBHlak8GmrhhEzy6bte48	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
231014395	a657288f-d550-467d-9476-4becc4c80159	Hmd Frwq Dny	h231014395@aast.com	t	\N	\N	\N	https://drive.google.com/open?id=1xkJCEt8K4l_OnmNmYWNvQ304xI_Ik1Vd	2026-05-10 10:49:58.696801+00	$pbkdf2-sha256$29000$sFaq9Z7T.n8vBeB8r1WKcQ$kx2w5NbA7IjB.egBmSWI9ZK5F3SWAFBrlbXvFHuL2u4
\.


--
-- Name: attendance_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.attendance_log_id_seq', 5, true);


--
-- Name: emotion_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.emotion_log_id_seq', 1, false);


--
-- Name: enrollments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.enrollments_id_seq', 1380, true);


--
-- Name: focus_strikes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.focus_strikes_id_seq', 1, false);


--
-- Name: incidents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.incidents_id_seq', 1, false);


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notifications_id_seq', 1, false);


--
-- Name: admins admins_auth_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_auth_user_id_key UNIQUE (auth_user_id);


--
-- Name: admins admins_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_email_key UNIQUE (email);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (admin_id);


--
-- Name: attendance_log attendance_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_log
    ADD CONSTRAINT attendance_log_pkey PRIMARY KEY (id);


--
-- Name: class_schedule class_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.class_schedule
    ADD CONSTRAINT class_schedule_pkey PRIMARY KEY (schedule_id);


--
-- Name: classes classes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_pkey PRIMARY KEY (class_id);


--
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (course_id);


--
-- Name: emotion_log emotion_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emotion_log
    ADD CONSTRAINT emotion_log_pkey PRIMARY KEY (id);


--
-- Name: enrollments enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT enrollments_pkey PRIMARY KEY (id);


--
-- Name: exams exams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exams
    ADD CONSTRAINT exams_pkey PRIMARY KEY (exam_id);


--
-- Name: focus_strikes focus_strikes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_strikes
    ADD CONSTRAINT focus_strikes_pkey PRIMARY KEY (id);


--
-- Name: incidents incidents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_pkey PRIMARY KEY (id);


--
-- Name: lecturers lecturers_auth_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lecturers
    ADD CONSTRAINT lecturers_auth_user_id_key UNIQUE (auth_user_id);


--
-- Name: lecturers lecturers_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lecturers
    ADD CONSTRAINT lecturers_email_key UNIQUE (email);


--
-- Name: lecturers lecturers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lecturers
    ADD CONSTRAINT lecturers_pkey PRIMARY KEY (lecturer_id);


--
-- Name: lectures lectures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lectures
    ADD CONSTRAINT lectures_pkey PRIMARY KEY (lecture_id);


--
-- Name: materials materials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.materials
    ADD CONSTRAINT materials_pkey PRIMARY KEY (material_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: students students_auth_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_auth_user_id_key UNIQUE (auth_user_id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (student_id);


--
-- Name: attendance_log attendance_log_lecture_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_log
    ADD CONSTRAINT attendance_log_lecture_id_fkey FOREIGN KEY (lecture_id) REFERENCES public.lectures(lecture_id);


--
-- Name: attendance_log attendance_log_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_log
    ADD CONSTRAINT attendance_log_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(student_id);


--
-- Name: class_schedule class_schedule_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.class_schedule
    ADD CONSTRAINT class_schedule_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(class_id) ON DELETE CASCADE;


--
-- Name: classes classes_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(course_id) ON DELETE CASCADE;


--
-- Name: classes classes_lecturer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_lecturer_id_fkey FOREIGN KEY (lecturer_id) REFERENCES public.lecturers(lecturer_id) ON DELETE SET NULL;


--
-- Name: emotion_log emotion_log_lecture_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emotion_log
    ADD CONSTRAINT emotion_log_lecture_id_fkey FOREIGN KEY (lecture_id) REFERENCES public.lectures(lecture_id);


--
-- Name: emotion_log emotion_log_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emotion_log
    ADD CONSTRAINT emotion_log_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(student_id);


--
-- Name: enrollments enrollments_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT enrollments_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(class_id) ON DELETE CASCADE;


--
-- Name: enrollments enrollments_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT enrollments_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(student_id) ON DELETE CASCADE;


--
-- Name: exams exams_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exams
    ADD CONSTRAINT exams_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(class_id);


--
-- Name: exams exams_lecture_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exams
    ADD CONSTRAINT exams_lecture_id_fkey FOREIGN KEY (lecture_id) REFERENCES public.lectures(lecture_id);


--
-- Name: focus_strikes focus_strikes_lecture_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_strikes
    ADD CONSTRAINT focus_strikes_lecture_id_fkey FOREIGN KEY (lecture_id) REFERENCES public.lectures(lecture_id);


--
-- Name: focus_strikes focus_strikes_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_strikes
    ADD CONSTRAINT focus_strikes_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(student_id);


--
-- Name: incidents incidents_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(student_id);


--
-- Name: lectures lectures_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lectures
    ADD CONSTRAINT lectures_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(class_id);


--
-- Name: lectures lectures_lecturer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lectures
    ADD CONSTRAINT lectures_lecturer_id_fkey FOREIGN KEY (lecturer_id) REFERENCES public.lecturers(lecturer_id);


--
-- Name: materials materials_lecture_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.materials
    ADD CONSTRAINT materials_lecture_id_fkey FOREIGN KEY (lecture_id) REFERENCES public.lectures(lecture_id);


--
-- Name: materials materials_lecturer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.materials
    ADD CONSTRAINT materials_lecturer_id_fkey FOREIGN KEY (lecturer_id) REFERENCES public.lecturers(lecturer_id);


--
-- Name: notifications notifications_lecture_id_fk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_lecture_id_fk_fkey FOREIGN KEY (lecture_id_fk) REFERENCES public.lectures(lecture_id);


--
-- Name: notifications notifications_lecturer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_lecturer_id_fkey FOREIGN KEY (lecturer_id) REFERENCES public.lecturers(lecturer_id);


--
-- Name: notifications notifications_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(student_id);


--
-- PostgreSQL database dump complete
--

\unrestrict JMclcjkgaWwlG2aCcrZitRaSETAvILCu4ZS3bWShfihoWxzXRaRT6INrDKeq6Iu

