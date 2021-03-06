USE [AnalitDB]
GO
/****** Object:  StoredProcedure [edu].[p_KG_Children_visitng_by_priv]    Script Date: 9/27/2020 10:51:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [edu].[p_KG_Children_visitng_by_priv]


AS
BEGIN

declare @date date
set @date = getdate() - 1
while @date < getdate() - 1 begin
	insert into edu.KG_Children_visitng_by_priv (date, child_visitng, unit_id, ch_priv_stat) 
	
select @date, count (group_child.child_id) as child_visitng, g1.unit_id, case when ch_priv.child_id >  0 then 'priv' else 'not_priv' end as ch_priv_stat

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
	



	where g.status = 1 and p.date <= @date and (p.close_date is null or p.close_date > @date)
	-- убрал 14-летних детей
	and child_id not in (377408, 123381)
	and child_id in (select id from [AnalitDB].[edu].[KG_Children_vers2])
	group by p.child_id
	) as group_child
	
	
	join [AnalitDB].[edu].[KG_Groups] g1 on group_child.group_id = g1.id
	left join (
	SELECT  
    distinct  [child_id]
      
  FROM [AnalitDB].[edu].[KG_Declarations_vers2]
  where id in (
SELECT [owner_id]
  FROM [AnalitDB].[edu].[KG_Declarations_Privilege_vers2]
  where date <= @date)
  ) ch_priv on ch_priv.child_id = group_child.child_id

group by 
	unit_id, case when ch_priv.child_id >  0 then 'priv' else 'not_priv' end


set @date = dateadd(day,1,@date)
end

END
