--2. Подумать, какие операции являются транзакционными, и написать несколько примеров с транзакционными запросами.

--Например:
--перевод документа в архив (удалить из одной таблицы, добавить в другую таблицу).
--перемещение письма между папками в почте.
--перевод сотрудника из одного отдела в другой:
set autocommit=0;
Start transaction;
update dept_emp de set de.to_date = curdate() where de.emp_no = 10010 and de.to_date = '9999-01-01';
insert into dept_emp value (10010, 'd007', curdate(), '9999-01-01');
commit;

--3. Проанализировать несколько запросов с помощью EXPLAIN.
--Поиск текущих сотрудников какого-либо отдела, которые перевелись из других отделов
SELECT * FROM dept_emp de
WHERE
de.to_date = '9999-01-01'
AND de.dept_no = 'd006'
AND EXISTS (SELECT * FROM dept_emp de2
			WHERE
            de2.emp_no = de.emp_no
			AND de.dept_no <> de2.dept_no);        

--время выполнения 0.032 sec / 0.203 sec
--+----+-------------+-------+------------+------+------------------------+---------+---------+---------------------+-------+----------+------------------------------------------+
| id | select_type | table | partitions | type | possible_keys          | key     | key_len | ref                 | rows  | filtered | Extra                                    |
+----+-------------+-------+------------+------+------------------------+---------+---------+---------------------+-------+----------+------------------------------------------+
|  1 | SIMPLE      | de    | NULL       | ref  | PRIMARY,emp_no,dept_no | dept_no | 16      | const               | 36162 |    10.00 | Using index condition; Using where       |
|  1 | SIMPLE      | de2   | NULL       | ref  | PRIMARY,emp_no         | emp_no  | 4       | employees.de.emp_no |     1 |    90.00 | Using where; Using index; FirstMatch(de) |
+----+-------------+-------+------------+------+------------------------+---------+---------+---------------------+-------+----------+------------------------------------------+
--сначала в dept_emp выполняется поиск по ключу dept_no(есть индекс), потом для найденной записи в таблице dept_emp выполняется поиск по ключу emp_no(есть индекс).

--количество текущих сотрудников и текущая сумма зарплат по отделам.
SELECT 
    a.sum_salary, a.count_emp, d.*
FROM
    departments d,
    (SELECT 
        SUM(s.salary) AS sum_salary,
            COUNT(s.emp_no) AS count_emp,
            de.dept_no
    FROM
        dept_emp de
    JOIN salaries s ON de.emp_no = s.emp_no
    WHERE
        s.to_date = '9999-01-01'
    AND de.to_date = '9999-01-01'
    GROUP BY de.dept_no) a
WHERE
    d.dept_no = a.dept_no

--время выполнения 2.890 sec / 0.000 sec
+----+-------------+------------+------------+-------+------------------------+-------------+---------+---------------------+--------+----------+------------------------------+
| id | select_type | table      | partitions | type  | possible_keys          | key         | key_len | ref                 | rows   | filtered | Extra                        |
+----+-------------+------------+------------+-------+------------------------+-------------+---------+---------------------+--------+----------+------------------------------+
|  1 | PRIMARY     | d          | NULL       | index | PRIMARY                | dept_name   | 162     | NULL                |      9 |   100.00 | Using index                  |
|  1 | PRIMARY     | <derived2> | NULL       | ref   | <auto_key0>            | <auto_key0> | 16      | employees.d.dept_no |    305 |   100.00 | NULL                         |
|  2 | DERIVED     | de         | NULL       | ALL   | PRIMARY,emp_no,dept_no | NULL        | NULL    | NULL                | 331143 |    10.00 | Using where; Using temporary |
|  2 | DERIVED     | s          | NULL       | ref   | PRIMARY,emp_no         | PRIMARY     | 4       | employees.de.emp_no |      9 |    10.00 | Using where                  |
+----+-------------+------------+------------+-------+------------------------+-------------+---------+---------------------+--------+----------+------------------------------+
--full scan по таблице dept_emp, т.к. в фильтре использовано только неиндексированное поле to_date.