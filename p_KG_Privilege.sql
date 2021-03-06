USE [AnalitDB]
GO
/****** Object:  StoredProcedure [edu].[p_KG_Privilege]    Script Date: 9/27/2020 10:55:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [edu].[p_KG_Privilege]


AS
BEGIN


declare @date date
set @date = getdate() - 1
while @date <= getdate() - 1   begin
	insert into edu.KG_Children_privilege (date, cnt_child, mo_id, privilege_id, age) 
	SELECT @date, count (p.[owner_id]) as child_cnt
      ,du.unit_id as mo_id
	  ,p.[privilege_id]
	  ,(datediff(year,(0),datediff(day,[birthdate],@date))) as age
  FROM [AnalitDB].[edu].[KG_Declarations_Privilege_tmp] p
  join [AnalitDB].[edu].[KG_Declarations_vers2] d 
  on d.id = p.owner_id 
  join [AnalitDB].[edu].[KG_Children_vers2] c on c.id = d.child_id
  -- Отбираем последние дс, в заявлениях du
  join (
  SELECT mddu.owner_id
      ,[unit_id]
      ,[ord]
      ,[date]
      -- ,[privilege_id] убрал как неиспользуемое
  FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2] du1
  join (
  SELECT  [owner_id]
      ,max ([date]) as max_date
  FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2]
 where date <=  @date and ord = 1
 group by [owner_id]
 ) mddu on mddu.owner_id = du1.owner_id and mddu.max_date = du1.date
 -- Конец отбора последних ДС в заявлениях
  ) du on du.owner_id = p.owner_id
  -- join [AnalitDB].[edu].[KG_Unit] u on u.id = du.unit_id
  where  p.id in
  -- Отбираем последние "льготные" заявления
  (SELECT 
      max ([id]) as maxid
  FROM [AnalitDB].[edu].[KG_Declarations_Privilege_tmp] dp
  join (
SELECT  [owner_id]
      ,max ([date]) as maxd
  FROM [AnalitDB].[edu].[KG_Declarations_Privilege_tmp]
  where date <= @date
group by   [owner_id]) mdt
on mdt.owner_id = dp.owner_id and mdt.maxd = dp.date
group by mdt.owner_id, [date])
and p.owner_id in (
SELECT [id]
  FROM [AnalitDB].[edu].[KG_Declarations_vers2]
  where child_id in (
  SELECT  child_id
		FROM [AnalitDB].[edu].[KG_Placement_vers2] p
	join (
	SELECT [group_id]
      ,[date]
      ,[status]
	FROM [AnalitDB].[edu].[KG_GroupFields]
	where date = @date
	) g
	on p.group_id = g.group_id
	where g.status = 1 and p.date <= @date and (p.close_date is null or p.close_date > @date)

	union

	 SELECT child_id
  FROM [AnalitDB].[edu].[KG_Declarations_vers2] join (
  -- К списку заявлением присоединяем заявления с последними статусами  (1, 3, 7)
select d.owner_id, d.status_id, d.date from [AnalitDB].[edu].[KG_Declarations_Status_vers2] d join 
-- показываем самую позднюю дату и для каждого заявления, при условии что дата не позднее установленной
(
select max (date) as max_date, [owner_id] 
from (SELECT [owner_id]
      ,[status_id]
      ,[date]
  FROM [AnalitDB].[edu].[KG_Declarations_Status_vers2]
  where date <= @date) del_by_date
group by [owner_id]) as max_date_declaration
on max_date_declaration.max_date = date and [max_date_declaration].[owner_id] = d.[owner_id]
where status_id  in (1, 3, 7, 13)) as tmp
on [AnalitDB].[edu].[KG_Declarations_vers2].id = tmp.owner_id
-- из списка исключаем детей, которые дублируют детей, имевшихся в таблице  Placement
/* В БД имеет место ситуация, когда на одного ребёнка заводятся несколько id записей. При этом, соответственно, эти несколько
записей должны быть подсчитаны один раз, и правильно.
Для этого все дети по которым есть заявления, сравниваются друг с другом, по показателям id, имя, дата рождения, и 
реквизиты свидетельства о рождении. Если совпадают имя, дата рождения и свидетельство о рождении, считается, что это
один ребёнок, на которого заведено несколько id. Сравнивать только по свидетельствам о рождении нельзя, поскольку есть
существенное количество свидетельств о рождении с одним номером, но по разным детям.
Если ребёнок есть в таблице  [KG_Placement], значит это реальный ребёнок. "Дубли" это ребёнка не должны учитываться для
расчёта показателей.
*/
where child_id not in (
SELECT dbl.child_id as sec_child_id
  FROM [AnalitDB].[edu].[KG_Declarations_vers2] d
  join [AnalitDB].[edu].[KG_Children_vers2] c
  on d.child_id = c.id
  join (
  -- ищем детей с одинаковыми именами, датами рождения, и данными свидетельств о рождении, при этом с разными id.
  -- начало выборки dbl
  SELECT distinct d1.[child_id], c1.name,  c1.birthdate, certificate
  FROM [AnalitDB].[edu].[KG_Declarations_vers2] d1
  join [AnalitDB].[edu].[KG_Children_vers2] c1
  on d1.child_id = c1.id
  ) as dbl
  on d.child_id <> dbl.child_id and c.name = dbl.name and dbl.birthdate = c.birthdate and c.certificate = dbl.certificate
   where d.child_id in (
   SELECT distinct child_id
  FROM [AnalitDB].[edu].[KG_Placement_vers2] p
  join (
  SELECT [group_id]
      ,[date]
      ,[status]
  FROM [AnalitDB].[edu].[KG_GroupFields]
  where date = @date
  ) g
  on p.group_id = g.group_id
where g.status in (1) and p.date <= @date and (p.close_date is null or p.close_date > @date)
  )
  
  )
-- конец отбора "дублирующих" детей
-- из списка детей исключаем детей, которые есть в таблице  Placement
and child_id not in (
   SELECT distinct child_id
  FROM [AnalitDB].[edu].[KG_Placement_vers2] p
  join (
  SELECT [group_id]
      ,[date]
      ,[status]
  FROM [AnalitDB].[edu].[KG_GroupFields]
  where date = @date
  ) g
  on p.group_id = g.group_id
where g.status = 1 and p.date <= @date and (p.close_date is null or p.close_date > @date))
-- из списка исключаем детей, которые зачислены в плановые группы
and child_id not in (
SELECT child_id
  FROM [AnalitDB].[edu].[KG_Placement_vers2] p
  join (
  SELECT [group_id]
      ,[date]
      ,[status]
  FROM [AnalitDB].[edu].[KG_GroupFields]
  where date = @date
  ) g
  on p.group_id = g.group_id
where g.status = 2 and p.date <= @date and (p.close_date is null or p.close_date > @date)
--- Выше отобрали детей с статусом группы на назначенную дату — 2 — плановая.
--- Ниже, исключаем детей, у которых до назначенной даты, были статусы групп: Архивная или фактическая.
and child_id not in (
SELECT distinct child_id
  FROM [AnalitDB].[edu].[KG_Placement_vers2] p
  join (
  SELECT [group_id]
      ,[date]
      ,[status]
  FROM [AnalitDB].[edu].[KG_GroupFields]
  where date = @date
  ) g
  on p.group_id = g.group_id
where g.status in (0, 1) and p.date <= @date 
)
-- Отбираем детей, зачисленных в группы до 01 марта 2019 (до начала комплектования групп в прошлом году).
and p.date >= '2019-03-01'
)

union

SELECT count (distinct child_id)
  FROM [AnalitDB].[edu].[KG_Placement_vers2] p
  join (
  SELECT [group_id]
      ,[date]
      ,[status]
  FROM [AnalitDB].[edu].[KG_GroupFields]
  where date = @date
  ) g
  on p.group_id = g.group_id
where g.status = 2 and p.date <= @date and (p.close_date is null or p.close_date > @date)
--- Выше отобрали детей с статусом группы на назначенную дату — 2 — плановая.
--- Ниже, исключаем детей, у которых до назначенной даты, были статусы групп: Архивная или фактическая.
and child_id not in (
SELECT distinct child_id
  FROM [AnalitDB].[edu].[KG_Placement_vers2] p
  join (
  SELECT [group_id]
      ,[date]
      ,[status]
  FROM [AnalitDB].[edu].[KG_GroupFields]
  where date = @date
  ) g
  on p.group_id = g.group_id
where g.status in (0, 1) and p.date <= @date
)
-- Отбираем детей, зачисленных в группы до 01 марта 2019 (до начала комплектования групп в прошлом году).
and p.date >= '2019-03-01'
  )
  )
  group by du.unit_id, p.[privilege_id], (datediff(year,(0),datediff(day,[birthdate],@date)))
	




set @date = dateadd(day,1,@date)
end

END