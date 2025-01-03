-- Function to generate random JSON data
CREATE OR REPLACE FUNCTION generate_test_json()
RETURNS jsonb AS $$
DECLARE
    chars text := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
    prompt_length int;
    random_string text;
BEGIN
    prompt_length := floor(random() * 900 + 100)::int;  -- Random length between 100-1000
    SELECT string_agg(substr(chars, floor(random() * length(chars))::int + 1, 1), '')
    INTO random_string
    FROM generate_series(1, prompt_length);
    
    RETURN jsonb_build_object(
        'prompt', random_string,
        'key1', floor(random() * 1000),
        'key2', floor(random() * 1000),
        'key3', floor(random() * 1000)
    );
END;
$$ LANGUAGE plpgsql;

-- Create tables for timing comparison
-- 1. Table with 100 range partitions
CREATE TABLE range_partitioned (
    id bigserial,
    account_id int,
    created_at timestamp DEFAULT current_timestamp,
    data jsonb,
    PRIMARY KEY (account_id, id)
) PARTITION BY RANGE (account_id);

-- Create 100 range partitions covering 10,000 accounts
DO $$
BEGIN
    FOR i IN 0..99 LOOP
        EXECUTE format(
            'CREATE TABLE range_partitioned_p%s PARTITION OF range_partitioned 
             FOR VALUES FROM (%s) TO (%s)',
            i, i * 100 + 1, (i + 1) * 100 + 1
        );
    END LOOP;
END $$;

-- 2. Table with 10,000 individual partitions
CREATE TABLE hash_partitioned (
    id bigserial,
    account_id int,
    created_at timestamp DEFAULT current_timestamp,
    data jsonb,
    PRIMARY KEY (account_id, id)
) PARTITION BY HASH (account_id);

-- Create 10,000 hash partitions
DO $$
BEGIN
    FOR i IN 0..9999 LOOP
        EXECUTE format(
            'CREATE TABLE hash_partitioned_p%s PARTITION OF hash_partitioned 
             FOR VALUES WITH (modulus 10000, remainder %s)',
            i, i
        );
    END LOOP;
END $$;

-- 3. Table without partitions
CREATE TABLE non_partitioned (
    id bigserial,
    account_id int,
    created_at timestamp DEFAULT current_timestamp,
    data jsonb,
    PRIMARY KEY (account_id, id)
);

-- Function to test insertion performance
CREATE OR REPLACE FUNCTION test_insertion_performance(
    p_table_name text,
    p_account_count int,
    p_rows_per_account int
) RETURNS table (
    operation text,
    duration interval
) AS $$
DECLARE
    start_time timestamp;
    end_time timestamp;
BEGIN
    start_time := clock_timestamp();
    
    FOR account IN 1..p_account_count LOOP
        EXECUTE format(
            'INSERT INTO %I (account_id, data)
             SELECT %s, generate_test_json()
             FROM generate_series(1, %s)',
            p_table_name, account, p_rows_per_account
        );
        
        IF account % 100 = 0 THEN
            RAISE NOTICE 'Processed account %', account;
        END IF;
    END LOOP;
    
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        format('Insert into %s', p_table_name)::text,
        end_time - start_time;
END;
$$ LANGUAGE plpgsql;

-- Function to test deletion performance
CREATE OR REPLACE FUNCTION test_deletion_performance(
    p_table_name text,
    p_account_id int
) RETURNS table (
    operation text,
    duration interval
) AS $$
DECLARE
    start_time timestamp;
    end_time timestamp;
BEGIN
    start_time := clock_timestamp();
    
    EXECUTE format(
        'DELETE FROM %I WHERE account_id = %s',
        p_table_name, p_account_id
    );
    
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        format('Delete from %s where account_id = %s', p_table_name, p_account_id)::text,
        end_time - start_time;
END;
$$ LANGUAGE plpgsql;



-- Function to time the vacuum operation
CREATE OR REPLACE FUNCTION time_vacuum(
    p_table_name text
) RETURNS table (
    operation text,
    duration interval
) AS $$
DECLARE
    start_time timestamp;
    end_time timestamp;
BEGIN
    start_time := clock_timestamp();
    
    EXECUTE format(
        'VACUUM %I',
        p_table_name
    );
    
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        format('Vacuum %s', p_table_name)::text,
        end_time - start_time;
END;
$$ LANGUAGE plpgsql;

-- Run performance tests
-- Test with smaller sample: 10k accounts, 100 rows each
SELECT * FROM test_insertion_performance('range_partitioned', 10000, 100);
SELECT * FROM test_insertion_performance('hash_partitioned', 10000, 100);
SELECT * FROM test_insertion_performance('non_partitioned', 10000, 100);

-- Test single insert
SELECT * FROM test_insertion_performance('range_partitioned', 1, 1);
SELECT * FROM test_insertion_performance('hash_partitioned', 1, 1);
SELECT * FROM test_insertion_performance('non_partitioned', 1, 1);

-- Test deletion for one account
SELECT * FROM test_deletion_performance('range_partitioned', 5);
SELECT * FROM test_deletion_performance('hash_partitioned', 5);
SELECT * FROM test_deletion_performance('non_partitioned', 5);

-- Show table sizes
SELECT 
    schemaname, 
    tablename, 
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) as total_size
FROM pg_tables
WHERE tablename LIKE 'range_partitioned%'
   OR tablename LIKE 'hash_partitioned%'
   OR tablename = 'non_partitioned'
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC
LIMIT 10;

-- Show execution plans for deletions
EXPLAIN ANALYZE DELETE FROM range_partitioned WHERE account_id = 5;
EXPLAIN ANALYZE DELETE FROM hash_partitioned WHERE account_id = 5;
EXPLAIN ANALYZE DELETE FROM non_partitioned WHERE account_id = 5;