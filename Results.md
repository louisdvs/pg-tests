**Insert 100 rows for 10k accounts:**

Insert into range_partitioned | 00:01:47.762861
Insert into hash_partitioned | 00:01:52.061695
Insert into non_partitioned | 00:01:50.348944

**Insert an additional 1 row to each table:**

 Insert into range_partitioned | 00:00:00.001633 - Slowest
 Insert into hash_partitioned | 00:00:00.001152 - middle
 Insert into non_partitioned | 00:00:00.000765 - fastest

 Delete from range_partitioned where account_id = 5 | 00:00:00.002853
 Delete from hash_partitioned where account_id = 5 | 00:00:00.001088
 Delete from non_partitioned where account_id = 5 | 00:00:00.000544


 Delete on range_partitioned  (cost=0.29..180.47 rows=0 width=0) (actual time=0.047..0.047 rows=0 loops=1)
   Delete on range_partitioned_p0 range_partitioned_1
   ->  Index Scan using range_partitioned_p0_pkey on range_partitioned_p0 range_partitioned_1  (cost=0.29..180.47 rows=100 width=10) (actual time=0.045..0.045 rows=0 loops=1)
         Index Cond: (account_id = 5)
 Planning Time: 0.304 ms
 Execution Time: 0.093 ms
(6 rows)

----------------------------
 Delete on hash_partitioned  (cost=0.27..6.04 rows=0 width=0) (actual time=0.008..0.009 rows=0 loops=1)
   Delete on hash_partitioned_p2205 hash_partitioned_1
   ->  Index Scan using hash_partitioned_p2205_pkey on hash_partitioned_p2205 hash_partitioned_1  (cost=0.27..6.04 rows=1 width=10) (actual time=0.007..0.007 rows=0 loops=1)
         Index Cond: (account_id = 5)
 Planning Time: 0.205 ms
 Execution Time: 0.062 ms
(6 rows)

 Delete on non_partitioned  (cost=0.42..193.23 rows=0 width=0) (actual time=0.033..0.034 rows=0 loops=1)
   ->  Index Scan using non_partitioned_pkey on non_partitioned  (cost=0.42..193.23 rows=103 width=6) (actual time=0.032..0.032 rows=0 loops=1)
         Index Cond: (account_id = 5)
 Planning Time: 0.104 ms
 Execution Time: 0.062 ms
(5 rows)