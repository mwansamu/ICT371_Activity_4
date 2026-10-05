-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 2: Computer Laboratory Reservations
-- Student Number: 202405690

DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INTEGER NOT NULL
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(100) NOT NULL,
    workstations INTEGER NOT NULL,
    reservation_status VARCHAR(20) NOT NULL
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
('Database Practical', 10),
('Networking Practical', 3),
('Programming Practical', 20);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    workstations INTEGER;
BEGIN
    SELECT available_workstations INTO workstations
    FROM lab_sessions WHERE session_id = 1;

    IF workstations = 0 THEN
        RAISE NOTICE 'Session is full.';
    ELSIF workstations <= 3 THEN
        RAISE NOTICE 'Session is nearly full.';
    ELSE
        RAISE NOTICE 'Session has enough workstations.';
    END IF;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Workstation check %', i;
    END LOOP;
END $$;

-- 4. Reserve procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INTEGER,
    p_lecturer VARCHAR,
    p_workstations INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    available INTEGER;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION 'Number of workstations must be greater than zero.';
    END IF;

    SELECT available_workstations INTO available
    FROM lab_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF available IS NULL THEN
        RAISE EXCEPTION 'Session does not exist.';
    ELSIF available < p_workstations THEN
        RAISE NOTICE 'Reservation exceeds available capacity.';
    ELSE
        UPDATE lab_sessions
        SET available_workstations = available_workstations - p_workstations
        WHERE session_id = p_session_id;

        INSERT INTO reservations
        (session_id, lecturer, workstations, reservation_status)
        VALUES
        (p_session_id, p_lecturer, p_workstations, 'ACTIVE');

        RAISE NOTICE 'Reservation recorded successfully.';
    END IF;
END $$;

-- 5. Two valid reservations and one exceeding request
CALL reserve_workstations(1, 'Dr. Banda', 4);
CALL reserve_workstations(2, 'Mr. Phiri', 2);
CALL reserve_workstations(2, 'Ms. Tembo', 5);

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- 6. Cancel procedure
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    reserved_number INTEGER;
    current_status VARCHAR;
    session_number INTEGER;
BEGIN
    SELECT workstations, reservation_status, session_id
    INTO reserved_number, current_status, session_number
    FROM reservations
    WHERE reservation_id = p_reservation_id
    FOR UPDATE;

    IF current_status IS NULL THEN
        RAISE NOTICE 'Reservation does not exist.';
    ELSIF current_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation already cancelled. Workstations will not be released again.';
    ELSE
        UPDATE lab_sessions
        SET available_workstations = available_workstations + reserved_number
        WHERE session_id = session_number;

        UPDATE reservations
        SET reservation_status = 'CANCELLED'
        WHERE reservation_id = p_reservation_id;

        RAISE NOTICE 'Reservation cancelled successfully.';
    END IF;
END $$;

CALL cancel_reservation(1);
CALL cancel_reservation(1);

-- 7. Explicit cursor
DO $$
DECLARE
    session_cursor CURSOR FOR
        SELECT session_name, available_workstations
        FROM lab_sessions
        WHERE available_workstations <= 3;
    session_record RECORD;
BEGIN
    OPEN session_cursor;
    LOOP
        FETCH session_cursor INTO session_record;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Session with few workstations: %, Available: %',
            session_record.session_name, session_record.available_workstations;
    END LOOP;
    CLOSE session_cursor;
END $$;

-- 8. Invalid zero workstations with EXCEPTION
DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(1, 'Invalid Lecturer', 0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

-- 9. Final queries
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;
