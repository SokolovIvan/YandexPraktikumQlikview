USE [AnalitDB]
GO
/****** Object:  StoredProcedure [edu].[p_KG_Children_visitng_by_age_2month_3year]    Script Date: 9/27/2020 10:51:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [edu].[p_KG_Children_visitng_by_age_2month_3year]


AS
BEGIN

declare @date date
set @date = getdate() - 1
while @date < getdate() - 1 begin
	insert into edu.KG_Children_visitng_from2m_to3y (date, child_visitng, unit_id, age_cat_id, mo_id,  own_type, age) 
	
	select @date, count (child_id) as child_visitng, unit_id,  g1.age_cat_id, u.mo_id, u.own_type, age
from (
SELECT  child_id, max (g.group_id) as group_id,  DATEDIFF (day, c.birthdate, @date) / 365 as age
		FROM [AnalitDB].[edu].[KG_Placement_vers2] p
	join (
	SELECT [group_id]
      ,[date]
      ,[status]
	FROM [AnalitDB].[edu].[KG_GroupFields]
	where date = @date
	) g
	on p.group_id = g.group_id
	join [AnalitDB].[edu].[KG_Children_vers2] c
	on c.id = child_id
	where g.status = 1 and p.date <= @date and (p.close_date is null or p.close_date > @date)
	and datediff(month,(0),datediff(day,[birthdate],@date)) >= 2 and datediff(month,(0),datediff(day,[birthdate],@date)) <= 36
	group by child_id,  DATEDIFF (day, c.birthdate, @date) / 365
	) as group_child
	join [AnalitDB].[edu].[KG_Groups] g1 on group_child.group_id = g1.id
	join [AnalitDB].[edu].[KG_Unit] u on g1.unit_id = u.id
	group by group_id, unit_id,  g1.age_cat_id, max_count, u.mo_id, u.own_type, age

set @date = dateadd(day,1,@date)
end

END
