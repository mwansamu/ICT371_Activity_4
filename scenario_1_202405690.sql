-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 1: University Library Book Loans
-- Student Number: 202405690

DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    available_copies INTEGER NOT NULL
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    student_number VARCHAR(20) NOT NULL,
    book_id INTEGER REFERENCES books(book_id),
    quantity INTEGER NOT NULL,
    loan_status VARCHAR(20) NOT NULL
);

INSERT INTO books (title, available_copies) VALUES
('Database Systems', 5),
('Computer Networks', 2),
('Artificial Intelligence', 0);

-- 2. IF ELSIF ELSE
DO $$
DECLARE
    copies INTEGER;
BEGIN
    SELECT available_copies INTO copies FROM books WHERE book_id = 1;

    IF copies = 0 THEN
        RAISE NOTICE 'The book is unavailable.';
    ELSIF copies <= 2 THEN
        RAISE NOTICE 'The book has low copies.';
    ELSE
        RAISE NOTICE 'The book is sufficiently stocked.';
    END IF;
END $$;

-- 3. WHILE and numeric FOR
DO $$
DECLARE
    i INTEGER := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Overdue reminder %', i;
        i := i + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number: %', i;
    END LOOP;
END $$;

-- 4. Borrow procedure
CREATE OR REPLACE PROCEDURE borrow_book(
    p_student_number VARCHAR,
    p_book_id INTEGER,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    copies INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero.';
    END IF;

    SELECT available_copies INTO copies
    FROM books
    WHERE book_id = p_book_id
    FOR UPDATE;

    IF copies IS NULL THEN
        RAISE EXCEPTION 'Book does not exist.';
    ELSIF copies < p_quantity THEN
        RAISE NOTICE 'Not enough copies available.';
    ELSE
        UPDATE books
        SET available_copies = available_copies - p_quantity
        WHERE book_id = p_book_id;

        INSERT INTO book_loans
        (student_number, book_id, quantity, loan_status)
        VALUES
        (p_student_number, p_book_id, p_quantity, 'BORROWED');

        RAISE NOTICE 'Loan recorded successfully.';
    END IF;
END $$;

-- 5. Two valid loans and one exceeding request
CALL borrow_book('202405690', 1, 2);
CALL borrow_book('202405691', 2, 1);
CALL borrow_book('202405692', 2, 5);

SELECT * FROM books;
SELECT * FROM book_loans;

-- 6. Return procedure
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    loan_quantity INTEGER;
    current_status VARCHAR;
    book_number INTEGER;
BEGIN
    SELECT quantity, loan_status, book_id
    INTO loan_quantity, current_status, book_number
    FROM book_loans
    WHERE loan_id = p_loan_id
    FOR UPDATE;

    IF current_status IS NULL THEN
        RAISE NOTICE 'Loan does not exist.';
    ELSIF current_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan already returned. Copies will not be restored again.';
    ELSE
        UPDATE books
        SET available_copies = available_copies + loan_quantity
        WHERE book_id = book_number;

        UPDATE book_loans
        SET loan_status = 'RETURNED'
        WHERE loan_id = p_loan_id;

        RAISE NOTICE 'Loan returned successfully.';
    END IF;
END $$;

CALL return_book(1);
CALL return_book(1);

-- 7. Explicit cursor
DO $$
DECLARE
    book_cursor CURSOR FOR
        SELECT title, available_copies
        FROM books
        WHERE available_copies <= 2;
    book_record RECORD;
BEGIN
    OPEN book_cursor;
    LOOP
        FETCH book_cursor INTO book_record;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low-copy book: %, Copies: %',
            book_record.title, book_record.available_copies;
    END LOOP;
    CLOSE book_cursor;
END $$;

-- 8. Invalid zero quantity with EXCEPTION
DO $$
BEGIN
    BEGIN
        CALL borrow_book('202405693', 1, 0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

-- 9. Final queries
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;
