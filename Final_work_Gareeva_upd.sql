--Итоговый проект.

--1. Получите количество проектов, подписанных в 2023 году.
--В результат вывести одно значение количества.

select count(p.project_id)
from project p
where (p.sign_date::date between '2023-01-01' and '2023-12-31')


--2. Получите общий возраст сотрудников, нанятых в 2022 году.
--Результат вывести одним значением в виде "... years ... month ... days"
--Использование более 2х функций для работы с типом данных дата и время будет являться ошибкой.

select justify_days(sum(age(current_date, p.birthdate)))
from person p
join employee e on p.person_id = e.person_id 
where e.hire_date::date between '2022-01-01' and '2022-12-31'


--3. Получите сотрудников, у которого фамилия начинается на М, всего в фамилии 8 букв и который работает дольше других.
--Если таких сотрудников несколько, выведите одного случайного.
--В результат выведите два столбца, в первом должны быть имя и фамилия через пробел, во втором дата найма.

select concat(p.first_name,' ', p.last_name), e.hire_date  
from person p
join employee e on p.person_id = e.person_id
where p.last_name like 'М_______'
order by e.hire_date
limit 1; 


--4. Получите среднее значение полных лет сотрудников, которые уволены и не задействованы на проектах.
--В результат вывести одно среднее значение. Если получаете null, то в результат нужно вывести 0.

select coalesce(avg(extract(year from age(current_date, p.birthdate))), 0)
from person p
join employee e on p.person_id = e.person_id
where e.dismissal_date is not null and e.employee_id not in (
	select unnest(array_append(pj.employees_id, pj.project_manager_id))
	from project pj);


--5. Чему равна сумма полученных платежей от контрагентов из Жуковский, Россия.
--В результат вывести одно значение суммы.

select sum(pp.amount)
from country cr 
join city ct on cr.country_id = ct.country_id 
join address a on ct.city_id = a.city_id 
join customer c on a.address_id = c.address_id 
join project p on c.customer_id = p.customer_id 
join project_payment pp on p.project_id = pp.project_id 
where cr.country_name  = 'Россия' and ct.city_name = 'Жуковский' and pp.fact_transaction_timestamp is not null;


--6. Пусть руководитель проекта получает премию в 1% от стоимости завершенных проектов.
--Если взять завершенные проекты, какой руководитель проекта получит самый большой бонус?
--В результат нужно вывести идентификатор руководителя проекта, его ФИО и размер бонуса.
--Если таких руководителей несколько, предусмотреть вывод всех.

with cte as (
	select p.project_manager_id, concat(ps.last_name,' ', ps.first_name,' ', ps.middle_name) as ФИО, sum(p.project_cost)*0.01 as Размер_бонуса
	from project p 
	join employee e on p.project_manager_id = e.employee_id 
	join person ps on e.person_id = ps.person_id 
	where p.status = 'Завершен'
	group by p.project_manager_id, concat(ps.last_name,' ', ps.first_name,' ', ps.middle_name)
	order by sum(p.project_cost)*0.01 desc)
select *
from cte
where Размер_бонуса = (select max(Размер_бонуса) from cte)


with cte as (
	select p.project_manager_id, sum(p.project_cost) as sm, rank() over (order by sum(p.project_cost) desc) as r
	from project p 
	where p.status = 'Завершен'
	group by p.project_manager_id)
select cte.project_manager_id, concat(ps.last_name,' ', ps.first_name,' ', ps.middle_name) as ФИО, cte.sm*0.01 as Размер_бонуса
from cte
join employee e on cte.project_manager_id = e.employee_id 
join person ps on e.person_id = ps.person_id
where r=1


--7. Получите накопительный итог планируемых авансовых платежей на каждый месяц в отдельности.
--Выведите в результат те даты планируемых платежей, которые идут после преодаления накопительной суммой значения в 30 000 000
--Пример:
--дата		    накопление
--2022-06-14	28362946.20
--2022-06-20	29633316.30
--2022-06-23	34237017.30
--2022-06-24	46248120.30
--В результат должна попасть дата 2022-06-23

with cte as (
	select pp.plan_payment_date as plan_date, 
		sum(amount) over (partition by date_trunc('month', pp.plan_payment_date) order by pp.plan_payment_date) as sum_avans,
		date_trunc('month', pp.plan_payment_date) as month_of_pay
	from project_payment pp 
	where pp.payment_type = 'Авансовый'),
cte2 as (
	select plan_date, sum_avans, month_of_pay, row_number() over (partition by month_of_pay order by plan_date) as rn 
	from cte 
	where sum_avans>30000000)
select plan_date
from cte2
where rn=1

--8. Используя рекурсию посчитайте сумму фактических окладов сотрудников из структурного подразделения с id равным 17 и всех дочерних подразделений.
--В результат вывести одно значение суммы.

with recursive unit_str as (
	select cs.unit_id
	from company_structure cs
	where cs.unit_id = 17
	union all
	select cs.unit_id
	from company_structure cs
	join unit_str us on cs.parent_id = us.unit_id)
select sum(ep.salary*ep.rate)
from employee_position ep 
join position p on ep.position_id = p.position_id 
join unit_str us on p.unit_id = us.unit_id;


--9. Задание выполняется одним запросом.

--Сделайте сквозную нумерацию фактических платежей по проектам на каждый год в отдельности в порядке даты платежей.
--Получите платежи, сквозной номер которых кратен 5.
--Выведите скользящее среднее размеров платежей с шагом 2 строки назад и 2 строки вперед от текущей.
--Получите сумму скользящих средних значений.
--Получите сумму стоимости проектов на каждый год.
--Выведите в результат значение года (годов) и сумму проектов, где сумма проектов меньше, чем сумма скользящих средних значений.

with cte_rn as (
		select pp.amount as fact_payment, date_trunc('year', pp.fact_transaction_timestamp) as pay_year,
			row_number() over (partition by date_trunc('year', pp.fact_transaction_timestamp) order by pp.fact_transaction_timestamp) as rn
		from project_payment pp
		where pp.fact_transaction_timestamp is not null),
cte_rn5 as (
	select *
	from cte_rn
	where rn % 5 = 0),
cte_avg as (
	select pay_year,
		avg(fact_payment) over (partition by pay_year order by rn rows between 2 preceding and 2 following) as avg_amount
	from cte_rn5),
cte_sumavg as (
	select sum(avg_amount) as sum_avg
	from cte_avg),
cte_yearcost as (
	select date_trunc('year', p.sign_date) as year_date, sum(p.project_cost) as year_cost
	from project p
	group by date_trunc('year', p.sign_date))
select date_part('year', cy.year_date) as "year", cy.year_cost
from cte_yearcost cy
cross join cte_sumavg cs
where cy.year_cost < cs.sum_avg


--10. Создайте материализованное представление, которое будет хранить отчет следующей структуры:
--идентификатор проекта
--название проекта
--дата последней фактической оплаты по проекту
--размер последней фактической оплаты
--ФИО руководителей проектов
--Названия контрагентов
--В виде строки названия типов работ по каждому контрагенту

create materialized view ct_matview as
with cte_payment as (
	select row_number() over (partition by pp.project_id order by pp.fact_transaction_timestamp desc) as rn,
		pp.project_id, pp.fact_transaction_timestamp as cp_time, pp.amount as cp_pay
	from project_payment pp 
	where pp.fact_transaction_timestamp is not null),
cte_client as (
	select c.customer_id cc_id, c.customer_name cc_name, string_agg(tow.type_of_work_name, ',') cc_tow
	from customer c 
	join customer_type_of_work ctow on c.customer_id = ctow.customer_id 
	join type_of_work tow on ctow.type_of_work_id = tow.type_of_work_id 
	group by c.customer_id)
select p.project_id, p.project_name, concat(ps.last_name,' ', ps.first_name,' ', ps.middle_name) as ФИО,
	cp_time, cp_pay, cc.cc_name, cc.cc_tow
from project p
join cte_payment cp on cp.project_id = p.project_id and cp.rn=1
join cte_client cc on cc.cc_id = p.customer_id 
join employee e on p.project_manager_id = e.employee_id 
join person ps on e.person_id = ps.person_id;

select *
from ct_matview;

DROP MATERIALIZED view ct_matview;

