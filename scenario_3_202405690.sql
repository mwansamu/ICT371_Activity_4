-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 3: Student Hostel Room Allocation
-- Student Number: 202405690

DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;

CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) NOT NULL,
    available_bed_spaces INTEGER NOT NULL
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    student_number VARCHAR(20) NOT NULL,
    room_id INTEGER REFERENCES hostel_rooms(room_id),
    allocation_status VARCHAR(20) NOT NULL
);

INSERT INTO hostel_rooms (room_number, available_bed_spaces) VALUES
('A101', 3),
('A102', 1),
('A103', 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    spaces INTEGER;
BEGIN
    SELECT available_bed_spaces INTO spaces
    FROM hostel_rooms WHERE room_id = 1;

    IF spaces = 0 THEN
        RAISE NOTICE 'Room is full.';
    ELSIF spaces = 1 THEN
        RAISE NOTICE 'Room has one space left.';
    ELSE
        RAISE NOTICE 'Room has several spaces.';
    END IF;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Room check %', i;
    END LOOP;
END $$;

-- 4. Allocate procedure
CREATE OR REPLACE PROCEDURE allocate_room(
    p_student_number VARCHAR,
    p_room_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    spaces INTEGER;
BEGIN
    IF p_student_number IS NULL OR TRIM(p_student_number) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank.';
    END IF;

    SELECT available_bed_spaces INTO spaces
    FROM hostel_rooms
    WHERE room_id = p_room_id
    FOR UPDATE;

    IF spaces IS NULL THEN
        RAISE EXCEPTION 'Room does not exist.';
    ELSIF spaces <= 0 THEN
        RAISE NOTICE 'Room is full. Allocation not recorded.';
    ELSE
        UPDATE hostel_rooms
        SET available_bed_spaces = available_bed_spaces - 1
        WHERE room_id = p_room_id;

        INSERT INTO allocations
        (student_number, room_id, allocation_status)
        VALUES
        (p_student_number, p_room_id, 'ALLOCATED');

        RAISE NOTICE 'Student allocated successfully.';
    END IF;
END $$;

-- 5. Two valid allocations and one full-room request
CALL allocate_room('202405690', 1);
CALL allocate_room('202405691', 2);
CALL allocate_room('202405692', 3);

SELECT * FROM hostel_rooms;
SELECT * FROM allocations;

-- 6. Check-out procedure
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    current_status VARCHAR;
    room_number INTEGER;
BEGIN
    SELECT allocation_status, room_id
    INTO current_status, room_number
    FROM allocations
    WHERE allocation_id = p_allocation_id
    FOR UPDATE;

    IF current_status IS NULL THEN
        RAISE NOTICE 'Allocation does not exist.';
    ELSIF current_status = 'CHECKED_OUT' THEN
        RAISE NOTICE 'Allocation already checked out. Bed space will not be released again.';
    ELSE
        UPDATE hostel_rooms
        SET available_bed_spaces = available_bed_spaces + 1
        WHERE room_id = room_number;

        UPDATE allocations
        SET allocation_status = 'CHECKED_OUT'
        WHERE allocation_id = p_allocation_id;

        RAISE NOTICE 'Student checked out successfully.';
    END IF;
END $$;

CALL check_out(1);
CALL check_out(1);

-- 7. Explicit cursor
DO $$
DECLARE
    room_cursor CURSOR FOR
        SELECT room_number, available_bed_spaces
        FROM hostel_rooms
        WHERE available_bed_spaces <= 1;
    room_record RECORD;
BEGIN
    OPEN room_cursor;
    LOOP
        FETCH room_cursor INTO room_record;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/nearly full room: %, Available spaces: %',
            room_record.room_number, room_record.available_bed_spaces;
    END LOOP;
    CLOSE room_cursor;
END $$;

-- 8. Blank student number with EXCEPTION
DO $$
BEGIN
    BEGIN
        CALL allocate_room('', 1);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid student number handled: %', SQLERRM;
    END;
END $$;

-- 9. Final queries
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;
