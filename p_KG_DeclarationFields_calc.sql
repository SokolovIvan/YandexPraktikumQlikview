USE [AnalitDB]
GO
/****** Object:  StoredProcedure [edu].[p_KG_DeclarationFields_calc]    Script Date: 9/27/2020 10:52:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [edu].[p_KG_DeclarationFields_calc]
@p_date date,
@p_id int = null
as
begin
declare @date date = isnull(@p_date,getdate())
--Очистка
delete from edu.KG_DeclarationFields where ((@p_id is not null and owner_id = @p_id) or date = @date)
--Садики
insert into edu.KG_DeclarationFields(owner_id, date, name, value, [table], field)
select h.declaration_id as owner_id, h.date,
	case du.ord
		when 1 then 'firstID'
		when 2 then 'secondID'
		when 3 then 'thirdID'
		else 'currentID'
	end as name, u.id as value, h.[table], h.field
from edu.KG_DeclarationHistory h
inner join edu.KG_Declarations_Units du on du.owner_id = h.declaration_id
inner join edu.KG_Unit u on u.id = du.unit_id and u.name = h.value
inner join edu.KG_Declarations d on d.id = h.declaration_id
where  h.[table] = 'declaration_unit'
	and ( (@p_id is not null and @p_id = h.declaration_id) or h.date = @date)
--Льготы
insert into edu.KG_DeclarationFields(owner_id, date, name, value, [table], field)
select h.declaration_id as owner_id, h.date, 'privID' as name, p.id as value, h.[table], h.field
from edu.KG_DeclarationHistory h
inner join edu.KG_Declarations d on d.id = h.declaration_id
inner join edu.KG_Privilege p on p.name = h.value
where h.[table] = 'declaration_privilege'
	and ( (@p_id is not null and @p_id = h.declaration_id) or h.date = @date)

--Дети
insert into edu.KG_DeclarationFields(owner_id, date, name, value, [table], field)
select h.declaration_id as owner_id, h.date,
		case
			when h.field like 'address%' then 'addressFact'
			when h.field like 'reg_address%' then 'addressResid'
			when h.field like 'date_of_birth' then 'birthdate'
			when h.field like 'health_need_id' then 'healthProblem'
			when h.field like 'snils' then 'childSNILS'
			else ''
		end as name,
		h.value as value, h.[table], h.field
from edu.KG_DeclarationHistory h, edu.KG_Declarations d
where h.[table] = 'children' and d.id = h.declaration_id
	and ( (@p_id is not null and @p_id = h.declaration_id) or h.date = @date)
--Заявления

insert into edu.KG_DeclarationFields(owner_id, date, name, value, [table], field)
select h.declaration_id as owner_id, h.date,
		case(h.field)
			when 'date' then 'creationDate'
			when 'status_id' then 'statusID'
			when 'desired_date' then 'prefDate'
			when 'children_id' then 'childrenID'
			when 'consent_short_time_group' then 'shottermGroup'
			else ''
		end as name,
		h.value as value, h.[table], h.field
from edu.KG_DeclarationHistory h, edu.KG_Declarations d
where h.[table] = 'declaration' and d.id = h.declaration_id
	and ( (@p_id is not null and @p_id = h.declaration_id) or h.date = @date)

--Родители
insert into edu.KG_DeclarationFields(owner_id, date, name, value, [table], field)
select h.declaration_id as owner_id, h.date, 'parents' as name,	h.value as value, h.[table], h.field
from edu.KG_DeclarationHistory h, edu.KG_Declarations d
where h.[table] = 'delegate' and d.id = h.declaration_id
	and not exists(select 1 from edu.KG_DeclarationFields f where f.owner_id = d.id and f.date = h.date and f.name = 'parents')
	and ( (@p_id is not null and @p_id = h.declaration_id) or h.date = @date)
end