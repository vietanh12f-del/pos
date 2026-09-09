-- Apply before releasing the app version that writes order_fees.
begin;
alter table public.orders add column if not exists order_fees jsonb not null default '[]';
alter table public.orders add constraint orders_fees_array check (jsonb_typeof(order_fees) = 'array');
create table public.order_fee_types (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id),
 name text not null check (length(trim(name)) > 0), unique(store_id, name)
);
create table public.order_fee_settlements (
 fee_id uuid primary key, order_id uuid not null references public.orders(id),
 store_id uuid not null references public.stores(id), batch_id uuid not null,
 settled_at timestamptz not null default now(), settled_by uuid not null,
 undone_at timestamptz, undone_by uuid
);
create table public.order_fee_settlement_events (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id),
 batch_id uuid not null, fee_ids uuid[] not null, amount numeric not null,
 action text not null check(action in ('settle','undo')), actor_id uuid not null, created_at timestamptz not null default now()
);
alter table public.order_fee_types enable row level security;
alter table public.order_fee_settlements enable row level security;
alter table public.order_fee_settlement_events enable row level security;
create policy fee_types_read on public.order_fee_types for select to authenticated using (
 exists(select 1 from public.stores s where s.id=store_id and s.owner_id=auth.uid()) or
 exists(select 1 from public.store_members m where m.store_id=order_fee_types.store_id and m.user_id=auth.uid() and m.status='active'));
create policy fee_types_insert on public.order_fee_types for insert to authenticated with check (
 exists(select 1 from public.stores s where s.id=store_id and s.owner_id=auth.uid()) or
 exists(select 1 from public.store_members m where m.store_id=order_fee_types.store_id and m.user_id=auth.uid() and m.status='active'));
create policy settlements_owner_read on public.order_fee_settlements for select to authenticated using (
 exists(select 1 from public.stores s where s.id=store_id and s.owner_id=auth.uid()));
create policy settlement_events_owner_read on public.order_fee_settlement_events for select to authenticated using (
 exists(select 1 from public.stores s where s.id=store_id and s.owner_id=auth.uid()));

-- Returns one JSON value: no REST row limit, no date filter, includes cancelled orders.
create function public.list_employee_advances(p_store uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
 if not exists(select 1 from stores where id=p_store and owner_id=auth.uid()) then raise exception 'Owner only'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
 'id',f->>'id','orderID',o.id,'sequence',coalesce(o.sequence_number,'—'),
 'createdAt',o.created_at,'fee',f,'deleted',coalesce(o.is_deleted,false),
 'settledAt',case when st.undone_at is null then st.settled_at else null end,
 'settledBy',case when st.undone_at is null then st.settled_by else null end,
 'batchID',case when st.undone_at is null then st.batch_id else null end) order by o.created_at)
 from orders o cross join lateral jsonb_array_elements(o.order_fees) f
 left join order_fee_settlements st on st.fee_id=(f->>'id')::uuid
 where o.store_id=p_store and f->>'funding'='employee'), '[]'::jsonb);
end $$;

create function public.settle_employee_advances(p_store uuid,p_fees uuid[],p_expected jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare b uuid := gen_random_uuid(); r record; n integer := 0; total numeric := 0; person text;
begin
 if not exists(select 1 from stores where id=p_store and owner_id=auth.uid()) then raise exception 'Owner only'; end if;
 if coalesce(cardinality(p_fees),0)=0 then raise exception 'No fees selected'; end if;
 -- Serialise settlement and fee editing on the same order rows.
 for r in select o.id,f from orders o cross join lateral jsonb_array_elements(o.order_fees) f
 where o.store_id=p_store and (f->>'id')::uuid=any(p_fees) order by o.id for update of o loop
  if not coalesce(p_expected @> jsonb_build_array(r.f),false) then raise exception 'Fee amount or funding changed; refresh before confirming'; end if;
  if r.f->>'funding'<>'employee' then raise exception 'Not an employee advance'; end if;
  if person is not null and person<>r.f->>'employeeID' then raise exception 'Select one employee'; end if;
  person := r.f->>'employeeID';
  if exists(select 1 from order_fee_settlements where fee_id=(r.f->>'id')::uuid and undone_at is null) then raise exception 'Already settled; refresh'; end if;
  insert into order_fee_settlements(fee_id,order_id,store_id,batch_id,settled_by)
  values((r.f->>'id')::uuid,r.id,p_store,b,auth.uid())
  on conflict(fee_id) do update set batch_id=b,settled_at=now(),settled_by=auth.uid(),undone_at=null,undone_by=null;
  n:=n+1; total:=total+(r.f->>'amount')::numeric;
 end loop;
 if n<>(select count(distinct x) from unnest(p_fees) x) then raise exception 'Fees changed; refresh'; end if;
 insert into order_fee_settlement_events(store_id,batch_id,fee_ids,amount,action,actor_id) values(p_store,b,p_fees,total,'settle',auth.uid());
 return b;
end $$;
create function public.undo_employee_settlement(p_store uuid,p_batch uuid) returns void
language plpgsql security definer set search_path = public as $$
declare ids uuid[]; total numeric;
begin
 if not exists(select 1 from stores where id=p_store and owner_id=auth.uid()) then raise exception 'Owner only'; end if;
 update order_fee_settlements set undone_at=now(),undone_by=auth.uid() where store_id=p_store and batch_id=p_batch and undone_at is null;
 if not found then raise exception 'No active settlement'; end if;
 select fee_ids,amount into ids,total from order_fee_settlement_events where batch_id=p_batch and action='settle';
 insert into order_fee_settlement_events(store_id,batch_id,fee_ids,amount,action,actor_id) values(p_store,p_batch,ids,total,'undo',auth.uid());
end $$;

create function public.validate_order_fees() returns trigger language plpgsql security definer set search_path=public as $$
declare f jsonb;
begin
 if jsonb_typeof(new.order_fees)<>'array' then raise exception 'Invalid fees'; end if;
 if (select count(*) from jsonb_array_elements(new.order_fees)) <> (select count(distinct x->>'id') from jsonb_array_elements(new.order_fees) x) then raise exception 'Duplicate fee'; end if;
 for f in select * from jsonb_array_elements(new.order_fees) loop
  if jsonb_typeof(f->'amount') is distinct from 'number' or coalesce((f->>'amount')::numeric,0)<=0 or coalesce(trim(f->>'name'),'')='' or
     coalesce(f->>'bearer','') not in ('shop','customer') or coalesce(f->>'funding','') not in ('company','employee','customer') or
     (f->>'bearer'='shop' and f->>'funding'='customer') then raise exception 'Invalid fee'; end if;
  if exists(select 1 from orders o cross join lateral jsonb_array_elements(o.order_fees) x where o.id<>new.id and x->>'id'=f->>'id') then raise exception 'Fee ID already belongs to another order'; end if;
  if f->>'funding'='employee' and not exists(select 1 from store_members m where m.id=(f->>'employeeID')::uuid and m.store_id=new.store_id) then raise exception 'Invalid employee'; end if;
 end loop;
 if tg_op='UPDATE' then
  for f in select x from jsonb_array_elements(old.order_fees) x join order_fee_settlements st on st.fee_id=(x->>'id')::uuid and st.undone_at is null loop
   if not new.order_fees @> jsonb_build_array(f) then raise exception 'Undo reimbursement before changing a reimbursed fee'; end if;
  end loop;
 end if;
 return new;
end $$;
create trigger validate_order_fees before insert or update of order_fees on public.orders for each row execute function public.validate_order_fees();
revoke all on function public.list_employee_advances(uuid), public.settle_employee_advances(uuid,uuid[],jsonb), public.undo_employee_settlement(uuid,uuid) from public;
grant execute on function public.list_employee_advances(uuid), public.settle_employee_advances(uuid,uuid[],jsonb), public.undo_employee_settlement(uuid,uuid) to authenticated;
grant select, insert on public.order_fee_types to authenticated;
grant select on public.order_fee_settlements, public.order_fee_settlement_events to authenticated;
commit;
