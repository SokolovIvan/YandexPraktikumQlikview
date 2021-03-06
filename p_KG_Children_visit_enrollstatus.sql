USE [AnalitDB]
GO
/****** Object:  StoredProcedure [edu].[p_KG_Children_visit_enrollstatus]    Script Date: 9/27/2020 10:47:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [edu].[p_KG_Children_visit_enrollstatus]


AS
BEGIN

declare @date date
set @date = getdate() - 1

while @date <= getdate() - 1 begin
insert into edu.KG_Children_visit_status (date, child_cnt, unit_id, enroll_status, age)


select @date, count(lv.[child_id]), g.unit_id ,case 
  when [pref_date] < @date then 'enroll_late'
  else 'enroll_early'  
  end as enroll_status
  ,(datediff(year,(0),datediff(day,[birthdate],@date))) as age

   from (
SELECT  
      [child_id], group_id
  FROM [AnalitDB].[edu].[KG_list_visit] where [date] = @date) lv
  left join (
SELECT  [owner_id]
      ,[child_id] from (
SELECT  [id] as [owner_id]
      ,[child_id]
       ,ROW_NUMBER() over (partition by [child_id] order by [create_date] desc)  as id_1
  FROM [AnalitDB].[edu].[KG_Declarations_vers2]
  where [create_date] <= @date
  ) tmp where tmp.id_1 = 1) decl1 on lv.child_id = decl1.child_id
  left join (
  select [owner_id]
       ,[pref_date] from (
SELECT [owner_id]
       ,[pref_date]
  ,ROW_NUMBER() over (partition by [owner_id] order by [pref_date] desc)  as id_1 
  FROM [AnalitDB].[edu].[KG_Declarations_PrefDates_vers3]
  where [date_end] <=  @date
  ) tmp where tmp.id_1 = 1) pd1 on pd1.[owner_id] = decl1.[owner_id]
  
  join [AnalitDB].[edu].[KG_Groups] g on g.id = lv.group_id
  join [AnalitDB].[edu].[KG_Children_vers2] c on c.id = lv.child_id

  group by g.unit_id ,case 
  when [pref_date] < @date then 'enroll_late'
  else 'enroll_early'  
  end
  ,(datediff(year,(0),datediff(day,[birthdate],@date)))


set @date = dateadd(day,1,@date)
end

end



/*
select @date, count (child_id), unit_id, enroll_status, age from (
SELECT id_by_pref_date.child_id, du_del_by_date.unit_id, 
   -- Формируем статусы детей. Зачислены ранее желаемой даты, или зачислены позднее желаемой даты.
   case 
  when id_by_pref_date.pref_date >= @date then 'enroll_early'
  else 'enroll_late'
  end as enroll_status, 
  -- Окончание формирования статусов детей.
  datediff(year,(0),datediff(day,[birthdate],@date)) as age

  FROM [AnalitDB].[edu].[KG_Declarations] d
  -- Отбираем последние записи о желаемом ДС, не позднее установленной даты. du_del_by_date
  join (
  SELECT  du1.[owner_id]
      ,[unit_id]
      ,[ord]
      ,[date]
  FROM [AnalitDB].[edu].[KG_Declarations_Units] du1
  join (
  -- В заявлениях меняются желаемые ДС. Отбираем последние записи о желаемом ДС. du2
  SELECT  [owner_id]
      ,MAx ([date]) as max_date_declaration
  FROM [AnalitDB].[edu].[KG_Declarations_Units]
  where ord = 1
  group by [owner_id]) du2
  on du1.owner_id = du2.owner_id and du1.date = du2.max_date_declaration
  where ord = 1 and CONVERT (date, [date]) <= @date
  ) as du_del_by_date on d.id = du_del_by_date.owner_id
  join (
/* По каждому заявлению есть список предпочтительных ДС, в том числе с приоритетом 1. На одно заявление может быть несколько
таких ДС, выбранными в разные даты. Отбираем детей, по которым есть эти выбранные ДС, и максимальные даты выбора
таких детских садов. Для этого список заявлений джойним со списком выбранных ДС, с указанием максимальных
дат. Выборка - decl_max_date_by_child
*/

SELECT child_id, max(date) as max_date_unit
  FROM [AnalitDB].[edu].[KG_Declarations] d
  join (
  SELECT  du1.[owner_id]
      ,[unit_id]
      ,[ord]
      ,[date]
      ,[privilege_id]
  FROM [AnalitDB].[edu].[KG_Declarations_Units] du1
  join (
  -- Начало выборки du2
  SELECT  [owner_id]
      ,MAx ([date]) as max_date_declaration
  FROM [AnalitDB].[edu].[KG_Declarations_Units]
  where ord = 1
  group by [owner_id]) du2
  on du1.owner_id = du2.owner_id and du1.date = du2.max_date_declaration
  where ord = 1 and CONVERT (date, [date]) <= @date
  ) as du_del_by_date on d.id = du_del_by_date.owner_id
  group by child_id) as decl_max_date_by_child
  on decl_max_date_by_child.child_id = d.child_id and decl_max_date_by_child.max_date_unit = du_del_by_date.date
 /* Выше список детей, по которым есть предпочтительные ДС. Ниже - список детей, которые посещают ДС, к которому присоединяется
 список заявлений, где загружены последние даты желаемого зачисления. Выборка - id_by_pref_date
  */ 
   right join (
  SELECT  p.child_id, max (pref_date) as pref_date, p.date as enroll_date
		FROM [AnalitDB].[edu].[KG_Placement] p
	join (
	SELECT [group_id]
      ,[date]
      ,[status]
	FROM [AnalitDB].[edu].[KG_GroupFields]
	where date = @date
	) g
	on p.group_id = g.group_id
	-- Выше, список детей, которые посещают ДС.
	left join [AnalitDB].[edu].[KG_Declarations] d on d.child_id = p.child_id
	-- начало выборки max_date_pd1, последние предпочтительные даты зачисления.
	left join (
	select pd.owner_id, max_date, pref_date 
FROM [AnalitDB].[edu].[KG_Declarations_PrefDates] pd
join (
SELECT  max ([date]) as max_date
      ,[owner_id]
  FROM [AnalitDB].[edu].[KG_Declarations_PrefDates]
  where date <= @date
  group by [owner_id]
) as max_date_pd on max_date_pd.owner_id = pd.owner_id and max_date_pd.max_date = pd.date
	) max_date_pd1 on max_date_pd1.owner_id = d.id
	where g.status = 1 and p.date <= @date and (p.close_date is null or p.close_date > @date)
	group by p.child_id, p.date
  ) id_by_pref_date on id_by_pref_date.child_id = d.child_id
  -- Присоединяем список детей, чтобы получить даты рождения.
  join [AnalitDB].[edu].[KG_Children] c on c.id = id_by_pref_date.child_id
  ) as main
 group by unit_id, enroll_status, age
 */