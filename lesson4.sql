--1. Создать VIEW на основе запросов, которые вы сделали в ДЗ к уроку 3.

USE `employees`;
CREATE  OR REPLACE VIEW `v_dep_salary` AS
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
    d.dept_no = a.dept_no;


--2. Создать функцию, которая найдет менеджера по имени и фамилии.

USE `employees`;
DROP function IF EXISTS `find_manager`;

DELIMITER $$
USE `employees`$$
CREATE FUNCTION `find_manager` (fn varchar(14), ln varchar(16))
RETURNS INTEGER DETERMINISTIC
BEGIN
RETURN (SELECT 
    e.emp_no
FROM
    dept_manager dm
        JOIN
    employees e ON dm.emp_no = e.emp_no
WHERE
    e.first_name = fn
        AND e.last_name = ln);
END$$

DELIMITER ;

select find_manager('Isamu', 'Legleitner');

--3. Создать триггер, который при добавлении нового сотрудника будет 
--выплачивать ему вступительный бонус, занося запись об этом в таблицу salary.

DROP TRIGGER IF EXISTS `employees`.`employees_AFTER_INSERT`;

DELIMITER $$
USE `employees`$$
CREATE DEFINER = CURRENT_USER TRIGGER `employees`.`employees_AFTER_INSERT` AFTER INSERT ON `employees` FOR EACH ROW
BEGIN
INSERT INTO `employees`.`salaries` (`emp_no`, `salary`, `from_date`, `to_date`) VALUES (NEW.emp_no, '10000', CURRENT_DATE(), CURRENT_DATE());
END$$
DELIMITER ;

