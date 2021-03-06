USE [AnalitDB]
GO
/****** Object:  StoredProcedure [edu].[p_KG_Children_visiting]    Script Date: 9/27/2020 10:49:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [edu].[p_KG_Children_visiting]


AS
BEGIN

declare @date date
set @date = getdate() - 1
while @date < getdate() - 1 begin
	insert into edu.KG_Children_visitng (date, child_visitng, group_id, unit_id, age_cat_id, max_count, work_type_id) 
	
	select @date, count (group_child.child_id) as child_visitng, group_id, unit_id,  g1.age_cat_id, max_count, 
	case when g1.work_type_id = 4 then 'gst' else 'standart' end as work_type_id

from (
-- отбираются дети из таблицы плейсмент, с максимальным номером группы, и только действующие группы. выборка group_child
SELECT  p.child_id, max (g.group_id) as group_id
		FROM [AnalitDB].[edu].[KG_Placement_vers2] p
	join (
	SELECT [group_id]
      ,[date]
      ,[status]
	FROM [AnalitDB].[edu].[KG_GroupFields]
	where date = @date
	) g
	on p.group_id = g.group_id
	
	where g.status = 1 and p.date <= @date and (p.close_date is null or p.close_date > @date) and p.child_id in (select id from [AnalitDB].[edu].[KG_Children_vers2])
	and child_id not in (377408, 123381)
	group by child_id
	) as group_child
	join [AnalitDB].[edu].[KG_Groups] g1 on group_child.group_id = g1.id
	-- join [AnalitDB].[edu].[KG_Unit] u on g1.unit_id = u.id

	group by group_id, unit_id,  g1.age_cat_id, max_count, case when g1.work_type_id = 4 then 'gst' else 'standart' end

set @date = dateadd(day,1,@date)
end

END
