-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 4: Campus Clinic Medicine Dispensing
-- Student Number: 202405690

DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;

CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INTEGER NOT NULL
);

CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INTEGER REFERENCES medicines(medicine_id),
    student_number VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL,
    dispensing_status VARCHAR(20) NOT NULL
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
('Paracetamol', 20),
('Amoxicillin', 5),
('Vitamin C', 2);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    stock INTEGER;
BEGIN
    SELECT stock_quantity INTO stock
    FROM medicines WHERE medicine_id = 1;

    IF stock = 0 THEN
        RAISE NOTICE 'Medicine is out of stock.';
    ELSIF stock <= 5 THEN
        RAISE NOTICE 'Medicine is low on stock.';
    ELSE
        RAISE NOTICE 'Medicine is sufficiently stocked.';
    END IF;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Stock review day %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection %', i;
    END LOOP;
END $$;

-- 4. Dispense procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    stock INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Dispensing quantity must be greater than zero.';
    END IF;

    SELECT stock_quantity INTO stock
    FROM medicines
    WHERE medicine_id = p_medicine_id
    FOR UPDATE;

    IF stock IS NULL THEN
        RAISE EXCEPTION 'Medicine does not exist.';
    ELSIF stock < p_quantity THEN
        RAISE NOTICE 'Not enough medicine in stock.';
    ELSE
        UPDATE medicines
        SET stock_quantity = stock_quantity - p_quantity
        WHERE medicine_id = p_medicine_id;

        INSERT INTO dispensing_records
        (medicine_id, student_number, quantity, dispensing_status)
        VALUES
        (p_medicine_id, p_student_number, p_quantity, 'DISPENSED');

        RAISE NOTICE 'Medicine dispensed successfully.';
    END IF;
END $$;

-- 5. Two valid quantities and one exceeding stock
CALL dispense_medicine(1, '202405690', 4);
CALL dispense_medicine(2, '202405691', 2);
CALL dispense_medicine(3, '202405692', 5);

SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- 6. Reverse dispensing procedure
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    record_quantity INTEGER;
    current_status VARCHAR;
    medicine_number INTEGER;
BEGIN
    SELECT quantity, dispensing_status, medicine_id
    INTO record_quantity, current_status, medicine_number
    FROM dispensing_records
    WHERE record_id = p_record_id
    FOR UPDATE;

    IF current_status IS NULL THEN
        RAISE NOTICE 'Dispensing record does not exist.';
    ELSIF current_status = 'REVERSED' THEN
        RAISE NOTICE 'Record already reversed. Stock will not be restored again.';
    ELSE
        UPDATE medicines
        SET stock_quantity = stock_quantity + record_quantity
        WHERE medicine_id = medicine_number;

        UPDATE dispensing_records
        SET dispensing_status = 'REVERSED'
        WHERE record_id = p_record_id;

        RAISE NOTICE 'Dispensing record reversed successfully.';
    END IF;
END $$;

CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

-- 7. Explicit cursor
DO $$
DECLARE
    medicine_cursor CURSOR FOR
        SELECT medicine_name, stock_quantity
        FROM medicines
        WHERE stock_quantity <= 5;
    medicine_record RECORD;
BEGIN
    OPEN medicine_cursor;
    LOOP
        FETCH medicine_cursor INTO medicine_record;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low-stock medicine: %, Stock: %',
            medicine_record.medicine_name, medicine_record.stock_quantity;
    END LOOP;
    CLOSE medicine_cursor;
END $$;

-- 8. Negative quantity with EXCEPTION
DO $$
BEGIN
    BEGIN
        CALL dispense_medicine(1, '202405693', -2);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

-- 9. Final queries
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;
