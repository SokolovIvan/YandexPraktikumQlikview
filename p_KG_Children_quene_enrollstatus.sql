USE [AnalitDB]
GO
/****** Object:  StoredProcedure [edu].[p_KG_Children_quene_enrollstatus]    Script Date: 9/27/2020 10:46:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [edu].[p_KG_Children_quene_enrollstatus]


AS
BEGIN
-- delete edu.KG_Children_quene_status
declare @date date
set @date =  getdate() - 1
while @date < getdate() - 1 begin
insert into edu.KG_Children_quene_status (date, unit_id, child_cnt, pref_date_year, pref_date_month, age, need_kg_status, age_month, age_enroll)

SELECT @date, du_del_by_date.unit_id, count (id_by_pref_date.child_id) as child_cnt, YEAR (id_by_pref_date.pref_date), 
MONTH (id_by_pref_date.pref_date),
datediff(year,(0),datediff(day,[birthdate],@date)) as age,
case 
  when id_by_pref_date.pref_date >= @date then 'dont_need_kg'
  else 'need_kg' end as need_kg_status,

case 
  when datediff(year,(0),datediff(day,[birthdate],@date)) = 3 then datediff(month,(0),datediff(day,[birthdate],@date))
  else 0
  end as age_month,
  datediff(year,[birthdate],id_by_pref_date.pref_date) as age_enroll
  
  FROM [AnalitDB].[edu].[KG_Declarations_vers2] d
  -- Отбираем последние записи о желаемом ДС, не позднее установленной даты. du_del_by_date
  join (
  SELECT  du1.[owner_id]
      ,[unit_id]
      ,[ord]
      ,[date]
  FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2] du1
  join (
  -- В заявлениях меняются желаемые ДС. Отбираем последние записи о желаемом ДС. du2
  SELECT  [owner_id]
      ,MAx ([date]) as max_date_declaration
  FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2]
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
  FROM [AnalitDB].[edu].[KG_Declarations_vers2] d
  join (
  SELECT  du1.[owner_id]
      ,[unit_id]
      ,[ord]
      ,[date]
  --    ,[privilege_id]
  FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2] du1
  join (
  -- Начало выборки du2
  SELECT  [owner_id]
      ,MAx ([date]) as max_date_declaration
  FROM [AnalitDB].[edu].[KG_Declarations_Units_vers2]
  where ord = 1
  group by [owner_id]) du2
  on du1.owner_id = du2.owner_id and du1.date = du2.max_date_declaration
  where ord = 1 and CONVERT (date, [date]) <= @date
  ) as du_del_by_date on d.id = du_del_by_date.owner_id
  group by child_id) as decl_max_date_by_child
  on decl_max_date_by_child.child_id = d.child_id and decl_max_date_by_child.max_date_unit = du_del_by_date.date
  right join (
 select  lq.[child_id] as [child_id], max (pref_date) as pref_date
  FROM [AnalitDB].[edu].[KG_list_quene] lq
  left join [AnalitDB].[edu].[KG_Declarations_vers2] qd on qd.child_id = lq.child_id
  -- отбираем список заявлений с датами желаемого зачисления
  left join (
select qpd.owner_id, max_date, pref_date 
FROM [AnalitDB].[edu].[KG_Declarations_PrefDates] qpd
join (
SELECT  max ([date]) as max_date
      ,[owner_id]
  FROM [AnalitDB].[edu].[KG_Declarations_PrefDates]
  where date <= @date
  group by [owner_id]
) as max_date_pd on max_date_pd.owner_id = qpd.owner_id and max_date_pd.max_date = qpd.date
) max_date_pd1 on max_date_pd1.owner_id = qd.id
 where lq.date = @date
 group by lq.[child_id]
 ) id_by_pref_date on id_by_pref_date.child_id = d.child_id
  join [AnalitDB].[edu].[KG_Children_vers2] c on c.id = id_by_pref_date.child_id
  where datediff(year,(0),datediff(day,[birthdate],@date)) <= 7
  -- финальная группировка
  group by
  du_del_by_date.unit_id, YEAR (id_by_pref_date.pref_date), MONTH (id_by_pref_date.pref_date),
datediff(year,(0),datediff(day,[birthdate],@date)),
case 
  when id_by_pref_date.pref_date >= @date then 'dont_need_kg'
  else 'need_kg' end,

case 
  when datediff(year,(0),datediff(day,[birthdate],@date)) = 3 then datediff(month,(0),datediff(day,[birthdate],@date))
  else 0
  end,
  datediff(year,[birthdate],id_by_pref_date.pref_date)

set @date = dateadd(day,1,@date)
end

end