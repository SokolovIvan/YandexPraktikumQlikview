USE [AnalitDB]
GO
/****** Object:  StoredProcedure [edu].[p_KG_Children_directions]    Script Date: 9/27/2020 10:45:12 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [edu].[p_KG_Children_directions]


AS
BEGIN

declare @date date
set @date = getdate() - 1
while @date < getdate() - 1 begin

insert into edu.KG_Children_directions (date, dir_cnt, unit_id) 

SELECT @date, count (distinct dir.[id]) as dir_cnt
      
	  ,md_du2.unit_id
  FROM [AnalitDB].[edu].[KG_Directions_vers2] dir
  join [AnalitDB].[edu].[KG_Declarations_vers2] decl on dir.declaration_id = decl.id
-- md_du2
  left join (
  -- Здесь отобраны заявления и максимальные желаемые детские сады по этим заявлениям
SELECT  du.[owner_id]
      ,[unit_id]
  FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2] du
  join ( 
  SELECT  [owner_id]
      ,max ([date]) as mdd_du1
  FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2]
  group by [owner_id]
  ) md_du on du.owner_id = md_du.owner_id and du.date = md_du.mdd_du1
  where date > '2012-01-01' and du.date <= @date
  ) md_du2 on md_du2.owner_id = decl.id


  where dir.status_id in (2, 3, 4, 7) and dir.date <= @date and child_id in (
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
  SELECT distinct d1.[child_id], c1.name, c1.birthdate, certificate
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
  FROM [AnalitDB].[edu].[KG_GroupFields_now_vers2]
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
  FROM [AnalitDB].[edu].[KG_GroupFields_now_vers2]
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
  FROM [AnalitDB].[edu].[KG_GroupFields_now_vers2]
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
  FROM [AnalitDB].[edu].[KG_GroupFields_now_vers2]
  where date = @date
  ) g
  on p.group_id = g.group_id
where g.status in (0, 1) and p.date <= @date 
)
-- Отбираем детей, зачисленных в группы до 01 марта 2019 (до начала комплектования групп в прошлом году).
and p.date >= '2019-03-01'
)
)

group by md_du2.unit_id

set @date = dateadd(day,1,@date)
end

END