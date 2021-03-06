USE [AnalitDB]
GO
/****** Object:  StoredProcedure [edu].[p_KG_Children_quene_by_age]    Script Date: 9/27/2020 10:46:21 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [edu].[p_KG_Children_quene_by_age]


AS
BEGIN


declare @date date
set @date = getdate() - 1
while @date < getdate() - 1 begin


insert into edu.KG_Child_quene_by_age


SELECT @date as date,  d.child_id, du.unit_id, c.birthdate, d.create_date, d.source_id,  case 
when dp.owner_id > 0 then 'priv'
else 'not_priv'
end as priv_status, child_dir.child_id as dir_child_id, d.id as iddd
  
FROM [AnalitDB].[edu].[KG_Declarations_vers2] d 
join (
SELECT [child_id] FROM [AnalitDB].[edu].[KG_list_quene] where date = @date)
as tmp
on d.child_id = tmp.child_id
-- Добавляем таблицу, в которой отражены желаемые ДС с приоритетом 1 для зачисления. Поскольку заявлений может быть несколько, отбираем последнее

join (
select [owner_id], [unit_id]
from ( SELECT  [owner_id]
    ,[unit_id]
	,ROW_NUMBER() over (partition by [owner_id] order by [ord], [date] desc)  as id_1 
FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2]) tmp where tmp.id_1 = 1
) du on d.id = du.owner_id


join [AnalitDB].[edu].[KG_Children_vers2] c
on c.id = d.child_id

left join (
SELECT  [owner_id]
,max ([date]) as mddp
FROM [AnalitDB].[edu].[KG_Declarations_Privilege_vers2]
group by [owner_id]
) dp on dp.owner_id = d.id
-- присоединяем детей с направлениями 
left join (
SELECT distinct child_id
FROM [AnalitDB].[edu].[KG_Directions_vers2] dir_1
join [AnalitDB].[edu].[KG_Declarations_vers2] decl_1 on dir_1.declaration_id = decl_1.id
where dir_1.status_id in (2, 3, 7) and dir_1.date <= @date
) as child_dir on child_dir.child_id = c.id 


where d.id in (
select  max( d.id) as id  FROM [AnalitDB].[edu].[KG_Declarations_vers2] d 
join (
SELECT [child_id] FROM [AnalitDB].[edu].[KG_list_quene] where date = @date)
as tmp
on d.child_id = tmp.child_id
-- Добавляем таблицу, в которой отражены желаемые ДС с приоритетом 1 для зачисления. Поскольку заявлений может быть несколько, отбираем последнее

join (
SELECT  du1.[owner_id]
    ,[unit_id]
 
    ,[date]
 
FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2] du1
join (
SELECT  [owner_id]
    ,MAx ([date]) as max_date_declaration
FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2]
where ord = 1
group by [owner_id]) du2
on du1.owner_id = du2.owner_id and du1.date = du2.max_date_declaration
where ord = 1
) du on d.id = du.owner_id

join [AnalitDB].[edu].[KG_Children_vers2] c
on c.id = d.child_id

left join (
SELECT  [owner_id]
,max ([date]) as mddp
FROM [AnalitDB].[edu].[KG_Declarations_Privilege_vers2]
group by [owner_id]
) dp on dp.owner_id = d.id
-- присоединяем детей с направлениями 
left join (
SELECT distinct child_id
FROM [AnalitDB].[edu].[KG_Directions_vers2] dir_1
join [AnalitDB].[edu].[KG_Declarations_vers2] decl_1 on dir_1.declaration_id = decl_1.id
where dir_1.status_id in (2, 3, 7) and dir_1.date <= @date
) as child_dir on child_dir.child_id = c.id 
group by d.child_id
)
set @date = dateadd(day,1,@date)
end

END

