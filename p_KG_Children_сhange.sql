USE [AnalitDB]
GO
/****** Object:  StoredProcedure [edu].[p_KG_Children_сhange]    Script Date: 9/27/2020 10:52:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [edu].[p_KG_Children_сhange]


AS
BEGIN

declare @date date
set @date = getdate() - 1
while @date <= getdate() - 1 begin
	insert into [edu].[KG_list_change] ([date], child_id) 

select @date, child_id from ( -- начало выборки main_tmp
SELECT  distinct child_id
-- здесь отбираются дети посещающие ДС
  FROM [AnalitDB].[edu].KG_Placement_vers2 p
  join (
  SELECT [group_id]
      ,[date]
      ,[status]
  FROM [AnalitDB].[edu].[KG_GroupFields]
  where date = @date
  ) g
  on p.group_id = g.group_id
where g.status = 1 and p.date <= @date and (p.close_date is null or p.close_date > @date) 
-- конец выборки детей посещающих ДС. Ниже отбираются дети которые хотят сменить ДС или групу
and child_id in (
select child_id 
FROM [AnalitDB].[edu].KG_Declarations_vers2 
WHERE id in (
select d.owner_id from [AnalitDB].[edu].[KG_Declarations_Status_vers2] d join 
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
where status_id  in (8)
)
)
-- отбираем только тех детей, по которым есть заявления на смену ДС, с указанием этого ДС.
and child_id in (
select child_id 
FROM [AnalitDB].[edu].KG_Declarations_vers2 where id in (
select [owner_id]
FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2] where ord = 1)
)
) main_tmp

set @date = dateadd(day,1,@date)
end

-- по этим детям нет корректных желаемых ДС, поэтому их удаляем из очереди
delete from [edu].[KG_list_change] where child_id in (210467, 247927, 281990, 364301, 317718)
-- дети, которые хотят перевестись в несуществующие садики
delete from [edu].[KG_list_change] where child_id  in (288719, 222590, 357867, 357869, 238841)
-- заявление позднее чем изменение архивного заявления
-- delete from [edu].[KG_list_change] where child_id  in (284048)

END