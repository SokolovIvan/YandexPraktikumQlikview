USE [AnalitDB]
GO
/****** Object:  StoredProcedure [edu].[p_KG_Children_quene]    Script Date: 9/27/2020 10:45:54 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [edu].[p_KG_Children_quene]

AS
BEGIN

delete edu.KG_For_enroll
insert into edu.KG_For_enroll
 SELECT cq.child_id, cq.declaration_id, du.unit_id, du.ord, pd_maxdate.pref_date, YEAR(c.birthdate) as year_birth,
  2020 - YEAR(c.birthdate) as age
  FROM edu.KG_Child_quene cq
  left join (
  SELECT [date]
      ,pd.[owner_id]
      ,[pref_date]
  FROM [AnalitDB].[edu].[KG_Declarations_PrefDates] pd
  join (
  SELECT MAX ([date]) as max_date
      ,[owner_id]
  FROM [AnalitDB].[edu].[KG_Declarations_PrefDates]
  where date <= '2020-03-18'
  group by owner_id
  ) max_dates on max_dates.max_date = pd.date and max_dates.owner_id = pd.owner_id
) pd_maxdate on pd_maxdate.owner_id = cq.declaration_id
join (
SELECT  du1.[owner_id]
      ,du1.[unit_id]
      ,du1.[ord]
      ,du1.[date]
      ,du1.[privilege_id]
  FROM [AnalitDB].[edu].[KG_Declarations_Units] du1
  join (
  SELECT [owner_id]
      ,[ord]
      ,MAX([date]) as max_date
  FROM [AnalitDB].[edu].[KG_Declarations_Units]
  group by owner_id, ord) as max_date_unit
  on du1.owner_id = max_date_unit.owner_id and du1.ord = max_date_unit.ord and du1.date = max_date_unit.max_date
) du
on du.owner_id = cq.declaration_id
join [AnalitDB].[edu].[KG_Children] c on
c.id = cq.child_id


END