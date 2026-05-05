-- =================================================================
-- SETUP COMPLETO - Controle Empresas (banco novo) — v2 REORDENADO
-- Cole tudo no SQL Editor do Supabase e clique Run
-- =================================================================

-- =================================================================
-- BLOCO 0: CLEANUP (caso tenha sobrado algo de execução anterior)
-- =================================================================
drop trigger if exists on_auth_user_created on auth.users;

drop function if exists public.handle_new_auth_user();
drop function if exists public.is_active_user();
drop function if exists public.is_manager();
drop function if exists public.is_admin();
drop function if exists public.can_access_empresa(uuid);
drop function if exists public.set_atualizado_em();

drop table if exists public.usuario_gmail_tokens cascade;
drop table if exists public.empresa_obrigacoes_habilitadas cascade;
drop table if exists public.empresa_emails_cliente cascade;
drop table if exists public.extratos_arquivos cascade;
drop table if exists public.controle_contabil_extratos cascade;
drop table if exists public.contas_bancarias cascade;
drop table if exists public.arquivo_anotacoes cascade;
drop table if exists public.obrigacao_envios cascade;
drop table if exists public.obrigacao_tarefas cascade;
drop table if exists public.obrigacao_empresas cascade;
drop table if exists public.obrigacoes cascade;
drop table if exists public.checklist_fiscal cascade;
drop table if exists public.notificacoes cascade;
drop table if exists public.lixeira cascade;
drop table if exists public.logs cascade;
drop table if exists public.observacoes cascade;
drop table if exists public.documentos cascade;
drop table if exists public.responsaveis cascade;
drop table if exists public.rets cascade;
drop table if exists public.empresas cascade;
drop table if exists public.tags cascade;
drop table if exists public.servicos cascade;
drop table if exists public.usuarios cascade;
drop table if exists public.departamentos cascade;

-- =================================================================
-- BLOCO 1: TABELAS PRINCIPAIS (do supabase-schema.sql)
-- =================================================================

create table departamentos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table usuarios (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  email text not null unique,
  role text not null default 'usuario' check (role in ('admin', 'gerente', 'usuario')),
  departamento_id uuid references departamentos(id) on delete set null,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table servicos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  criado_em timestamptz not null default now()
);

create table tags (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  cor text not null default 'slate',
  criado_em timestamptz not null default now()
);

create table empresas (
  id uuid primary key default gen_random_uuid(),
  cadastrada boolean not null default false,
  cnpj text,
  codigo text not null default '',
  razao_social text,
  apelido text,
  data_abertura text,
  tipo_estabelecimento text not null default '' check (tipo_estabelecimento in ('', 'matriz', 'filial')),
  tipo_inscricao text not null default '' check (tipo_inscricao in ('', 'CNPJ', 'CPF', 'MEI', 'CEI', 'CAEPF', 'CNO')),
  servicos text[] not null default '{}',
  tags text[] not null default '{}',
  possui_ret boolean not null default false,
  inscricao_estadual text,
  inscricao_municipal text,
  regime_federal text,
  regime_estadual text,
  regime_municipal text,
  particularidades text,
  estado text,
  cidade text,
  bairro text,
  logradouro text,
  numero text,
  cep text,
  email text,
  telefone text,
  forma_envio text not null default ''
    check (forma_envio in ('', 'whatsapp', 'email', 'onvio', 'protocolo')),
  vencimentos_fiscais jsonb not null default '[]'::jsonb,
  cliente_desde date,
  desligada_em date,
  tributacao text
    check (tributacao in ('lucro_real', 'lucro_presumido', 'simples_nacional')),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table rets (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references empresas(id) on delete cascade,
  numero_pta text not null,
  nome text not null,
  vencimento date not null,
  ultima_renovacao date,
  ativo boolean not null default true,
  portaria varchar(20),
  tag_vencimento text,
  historico_vencimento jsonb not null default '[]'::jsonb
);

create table responsaveis (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references empresas(id) on delete cascade,
  departamento_id uuid not null references departamentos(id) on delete cascade,
  usuario_id uuid references usuarios(id) on delete set null,
  unique(empresa_id, departamento_id)
);

create table documentos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references empresas(id) on delete cascade,
  nome text not null,
  validade date not null,
  arquivo_url text,
  tag_vencimento text,
  historico_vencimento jsonb not null default '[]'::jsonb,
  departamentos_ids uuid[] not null default '{}',
  visibilidade text not null default 'publico'
    check (visibilidade in ('publico', 'departamento', 'confidencial', 'usuarios')),
  criado_por_id uuid references usuarios(id) on delete set null,
  usuarios_permitidos uuid[] not null default '{}',
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table observacoes (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references empresas(id) on delete cascade,
  texto text not null,
  autor_id uuid references usuarios(id) on delete set null,
  autor_nome text not null,
  criado_em timestamptz not null default now()
);

create table logs (
  id uuid primary key default gen_random_uuid(),
  em timestamptz not null default now(),
  user_id uuid references usuarios(id) on delete set null,
  user_nome text,
  action text not null check (action in ('login', 'logout', 'create', 'update', 'delete', 'alert')),
  entity text not null check (entity in ('empresa', 'usuario', 'departamento', 'documento', 'ret', 'notificacao')),
  entity_id uuid,
  message text not null,
  diff jsonb,
  deleted_em timestamptz,
  deleted_by_id uuid references usuarios(id) on delete set null,
  deleted_by_nome text
);

create table lixeira (
  id uuid primary key default gen_random_uuid(),
  tipo text not null default 'empresa' check (tipo in ('empresa', 'documento', 'observacao', 'ret')),
  empresa_data jsonb not null,
  documento_data jsonb,
  observacao_data jsonb,
  ret_data jsonb,
  empresa_id uuid,
  excluido_por_id uuid references usuarios(id) on delete set null,
  excluido_por_nome text not null,
  excluido_em timestamptz not null default now()
);

create table notificacoes (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  mensagem text not null,
  tipo text not null default 'info' check (tipo in ('info', 'sucesso', 'aviso', 'erro')),
  lida boolean not null default false,
  lidas_por uuid[] not null default '{}',
  empresa_id uuid references empresas(id) on delete set null,
  destinatarios uuid[] not null default '{}',
  criado_em timestamptz not null default now(),
  autor_id uuid references usuarios(id) on delete set null,
  autor_nome text
);

create table checklist_fiscal (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references empresas(id) on delete cascade,
  mes text not null,
  obrigacao text not null,
  concluido boolean not null default false,
  concluido_por_id uuid references usuarios(id) on delete set null,
  concluido_por_nome text,
  concluido_em timestamptz,
  observacao text,
  arquivo_url text,
  arquivo_nome text,
  arquivo_historico jsonb not null default '[]'::jsonb,
  status text check (status is null or status in ('feito', 'sem_obrigacao')),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (empresa_id, mes, obrigacao)
);

-- =================================================================
-- BLOCO 2: ÍNDICES BÁSICOS
-- =================================================================
create index idx_empresas_codigo on empresas(codigo);
create index idx_empresas_cnpj on empresas(cnpj);
create index idx_empresas_cliente_desde on empresas(cliente_desde);
create index idx_empresas_desligada_em on empresas(desligada_em);
create index idx_empresas_tributacao on empresas(tributacao);
create index idx_documentos_empresa on documentos(empresa_id);
create index idx_observacoes_empresa on observacoes(empresa_id);
create index idx_rets_empresa on rets(empresa_id);
create index idx_responsaveis_empresa on responsaveis(empresa_id);
create index idx_logs_em on logs(em desc);
create index idx_logs_deleted_em on logs(deleted_em);
create index idx_notificacoes_criado on notificacoes(criado_em desc);
create index idx_lixeira_excluido on lixeira(excluido_em desc);
create index idx_checklist_fiscal_mes on checklist_fiscal(mes);
create index idx_checklist_fiscal_empresa on checklist_fiscal(empresa_id);
create index idx_checklist_fiscal_mes_empresa on checklist_fiscal(mes, empresa_id);

-- =================================================================
-- BLOCO 3: SEED INICIAL
-- =================================================================
insert into departamentos (nome) values
  ('Cadastro'),
  ('Fiscal'),
  ('Contábil');

-- =================================================================
-- BLOCO 4: FUNÇÕES HELPER (criadas DEPOIS das tabelas referenciadas)
-- =================================================================

create or replace function public.set_atualizado_em()
returns trigger as $$
begin
  new.atualizado_em = now();
  return new;
end;
$$ language plpgsql;

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.usuarios u
    where u.id = auth.uid()
      and u.ativo = true
  );
$$;

create or replace function public.is_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.usuarios u
    where u.id = auth.uid()
      and u.ativo = true
      and (u.role = 'gerente' or u.role = 'admin')
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.usuarios u
    where u.id = auth.uid()
      and u.ativo = true
      and u.role = 'admin'
  );
$$;

create or replace function public.can_access_empresa(eid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_manager()
     or exists(
        select 1 from public.responsaveis r
        where r.empresa_id = eid
          and r.usuario_id = auth.uid()
     );
$$;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.usuarios set id = new.id
    where email = new.email and id != new.id;

  insert into public.usuarios (id, nome, email, role, ativo)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'nome', ''), split_part(new.email, '@', 1), 'Usuário'),
    new.email,
    'usuario',
    true
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_auth_user();

-- =================================================================
-- BLOCO 5: STORAGE BUCKET
-- =================================================================
insert into storage.buckets (id, name, public, file_size_limit)
values ('documentos', 'documentos', true, 10485760)
on conflict (id) do nothing;

drop policy if exists "Authenticated users can upload docs" on storage.objects;
create policy "Authenticated users can upload docs"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'documentos');

drop policy if exists "Public read access for docs" on storage.objects;
create policy "Public read access for docs"
  on storage.objects for select
  to public
  using (bucket_id = 'documentos');

drop policy if exists "Authenticated users can delete docs" on storage.objects;
create policy "Authenticated users can delete docs"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'documentos');

-- =================================================================
-- BLOCO 6: ENABLE RLS NAS TABELAS PRINCIPAIS
-- =================================================================
alter table departamentos enable row level security;
alter table usuarios enable row level security;
alter table servicos enable row level security;
alter table empresas enable row level security;
alter table rets enable row level security;
alter table responsaveis enable row level security;
alter table documentos enable row level security;
alter table observacoes enable row level security;
alter table logs enable row level security;
alter table lixeira enable row level security;
alter table notificacoes enable row level security;
alter table checklist_fiscal enable row level security;

-- =================================================================
-- BLOCO 7: POLICIES (agora as funções existem)
-- =================================================================

create policy departamentos_select on departamentos
  for select using (public.is_active_user());
create policy departamentos_insert on departamentos
  for insert with check (public.is_manager());
create policy departamentos_update on departamentos
  for update using (public.is_manager()) with check (public.is_manager());
create policy departamentos_delete on departamentos
  for delete using (public.is_manager());

create policy servicos_select on servicos
  for select using (public.is_active_user());
create policy servicos_insert on servicos
  for insert with check (public.is_manager());
create policy servicos_update on servicos
  for update using (public.is_manager()) with check (public.is_manager());
create policy servicos_delete on servicos
  for delete using (public.is_manager());

create policy usuarios_self_select on usuarios
  for select using (auth.uid() = id);

create policy empresas_select on empresas
  for select using (public.is_active_user());
create policy empresas_insert on empresas
  for insert with check (public.is_manager());
create policy empresas_update on empresas
  for update using (public.can_access_empresa(id))
  with check (public.can_access_empresa(id));
create policy empresas_delete on empresas
  for delete using (public.is_manager());

create policy responsaveis_select on responsaveis
  for select using (public.is_active_user());
create policy responsaveis_insert on responsaveis
  for insert with check (public.is_manager());
create policy responsaveis_update on responsaveis
  for update using (public.is_manager()) with check (public.is_manager());
create policy responsaveis_delete on responsaveis
  for delete using (public.is_manager());

create policy rets_select on rets
  for select using (public.is_active_user());
create policy rets_write on rets
  for all using (public.can_access_empresa(empresa_id))
  with check (public.can_access_empresa(empresa_id));

create policy documentos_select on documentos
  for select using (public.is_active_user());
create policy documentos_write on documentos
  for all using (public.can_access_empresa(empresa_id))
  with check (public.can_access_empresa(empresa_id));

create policy observacoes_select on observacoes
  for select using (public.is_active_user());
create policy observacoes_write on observacoes
  for all using (public.can_access_empresa(empresa_id))
  with check (public.can_access_empresa(empresa_id));

create policy logs_insert on logs
  for insert with check (public.is_active_user());
create policy logs_select on logs
  for select using (public.is_active_user());
create policy logs_update on logs
  for update using (public.is_admin())
  with check (public.is_admin());

create policy lixeira_all on lixeira
  for all using (public.is_manager())
  with check (public.is_manager());

create policy notificacoes_all on notificacoes
  for all using (public.is_active_user())
  with check (public.is_active_user());

create policy checklist_fiscal_select on checklist_fiscal
  for select using (public.is_active_user());
create policy checklist_fiscal_write on checklist_fiscal
  for all using (public.can_access_empresa(empresa_id))
  with check (public.can_access_empresa(empresa_id));

-- =================================================================
-- BLOCO 8: OBRIGAÇÕES
-- =================================================================

create table obrigacoes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  codigo text,
  departamento text not null check (departamento in ('fiscal', 'pessoal', 'contabil', 'cadastro')),
  esfera text not null default 'federal' check (esfera in ('federal', 'estadual', 'municipal', 'interna')),
  frequencia text not null check (
    frequencia in ('mensal', 'bimestral', 'trimestral', 'quadrimestral', 'semestral', 'anual', 'eventual')
  ),
  tipo_data_legal text not null default 'dia_util' check (tipo_data_legal in ('dia_util', 'dia_corrido', 'dia_fixo')),
  dia_data_legal int not null default 20 check (dia_data_legal between 1 and 31),
  tipo_data_meta text not null default 'dia_util' check (tipo_data_meta in ('dia_util', 'dia_corrido', 'dia_fixo')),
  dia_data_meta int not null default 15 check (dia_data_meta between 1 and 31),
  competencia_offset int not null default -1,
  pontuacao int not null default 1,
  agrupador text,
  notificar_cliente boolean not null default true,
  gera_multa boolean not null default true,
  auto_concluir boolean not null default true,
  palavras_chave text[] not null default '{}',
  template_email_assunto text,
  template_email_corpo text,
  descricao text,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index idx_obrigacoes_departamento on obrigacoes (departamento);
create index idx_obrigacoes_ativo on obrigacoes (ativo);

create table obrigacao_empresas (
  obrigacao_id uuid not null references obrigacoes(id) on delete cascade,
  empresa_id uuid not null references empresas(id) on delete cascade,
  criado_em timestamptz not null default now(),
  primary key (obrigacao_id, empresa_id)
);

create index idx_oe_empresa on obrigacao_empresas (empresa_id);

create table obrigacao_tarefas (
  id uuid primary key default gen_random_uuid(),
  obrigacao_id uuid not null references obrigacoes(id) on delete cascade,
  empresa_id uuid not null references empresas(id) on delete cascade,
  competencia text not null,
  data_legal date,
  data_meta date,
  status text not null default 'aberta' check (
    status in ('aberta', 'em_andamento', 'aguardando_cliente', 'concluida', 'atrasada', 'cancelada')
  ),
  responsavel_id uuid references usuarios(id) on delete set null,
  concluida_em timestamptz,
  concluida_por_id uuid references usuarios(id) on delete set null,
  arquivo_url text,
  vencimento_detectado date,
  competencia_detectada text,
  valor_detectado numeric(14,2),
  observacao text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (obrigacao_id, empresa_id, competencia)
);

create index idx_tarefas_empresa on obrigacao_tarefas (empresa_id);
create index idx_tarefas_competencia on obrigacao_tarefas (competencia);
create index idx_tarefas_status on obrigacao_tarefas (status);
create index idx_tarefas_responsavel on obrigacao_tarefas (responsavel_id);

create table obrigacao_envios (
  id uuid primary key default gen_random_uuid(),
  tarefa_id uuid not null references obrigacao_tarefas(id) on delete cascade,
  enviado_por_id uuid references usuarios(id) on delete set null,
  remetente_email text,
  destinatarios text[] not null default '{}',
  cc text[] not null default '{}',
  assunto text,
  corpo text,
  arquivo_url text,
  tracking_id uuid not null default gen_random_uuid(),
  enviado_em timestamptz not null default now(),
  aberto_em timestamptz,
  ultimo_aberto_em timestamptz,
  total_aberturas int not null default 0,
  clicado_em timestamptz,
  ultimo_clicado_em timestamptz,
  total_cliques int not null default 0,
  bounce boolean not null default false,
  erro text,
  user_agent_abertura text,
  ip_abertura text
);

create index idx_envios_tarefa on obrigacao_envios (tarefa_id);
create index idx_envios_tracking on obrigacao_envios (tracking_id);

alter table obrigacoes enable row level security;
alter table obrigacao_empresas enable row level security;
alter table obrigacao_tarefas enable row level security;
alter table obrigacao_envios enable row level security;

create policy obrigacoes_select on obrigacoes
  for select using (public.is_active_user());
create policy obrigacoes_write on obrigacoes
  for all using (public.is_admin())
  with check (public.is_admin());

create policy obrigacao_empresas_select on obrigacao_empresas
  for select using (public.is_active_user());
create policy obrigacao_empresas_write on obrigacao_empresas
  for all using (public.is_admin())
  with check (public.is_admin());

create policy obrigacao_tarefas_select on obrigacao_tarefas
  for select using (public.is_active_user());
create policy obrigacao_tarefas_write on obrigacao_tarefas
  for all using (public.can_access_empresa(empresa_id))
  with check (public.can_access_empresa(empresa_id));

create policy obrigacao_envios_select on obrigacao_envios
  for select using (public.is_active_user());
create policy obrigacao_envios_write on obrigacao_envios
  for all using (
    exists (
      select 1 from obrigacao_tarefas t
      where t.id = obrigacao_envios.tarefa_id
        and public.can_access_empresa(t.empresa_id)
    )
  ) with check (
    exists (
      select 1 from obrigacao_tarefas t
      where t.id = obrigacao_envios.tarefa_id
        and public.can_access_empresa(t.empresa_id)
    )
  );

-- =================================================================
-- BLOCO 9: CONTROLE CONTÁBIL (com v2 e v3 ja aplicados)
-- =================================================================

create table contas_bancarias (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references empresas(id) on delete cascade,
  nome text not null,
  agencia text,
  conta text,
  ordem int not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index idx_contas_bancarias_empresa on contas_bancarias(empresa_id);
create index idx_contas_bancarias_ativo on contas_bancarias(empresa_id, ativo);

alter table contas_bancarias enable row level security;
create policy contas_bancarias_select on contas_bancarias
  for select using (public.is_active_user());
create policy contas_bancarias_write on contas_bancarias
  for all using (public.can_access_empresa(empresa_id))
  with check (public.can_access_empresa(empresa_id));

create table controle_contabil_extratos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references empresas(id) on delete cascade,
  conta_bancaria_id uuid not null references contas_bancarias(id) on delete cascade,
  mes text not null,
  status text not null check (status in ('feito', 'recebido_pendente', 'sem_movimento')),
  marcado_por_id uuid references usuarios(id) on delete set null,
  marcado_por_nome text,
  marcado_em timestamptz not null default now(),
  observacao text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (conta_bancaria_id, mes)
);

create index idx_cce_empresa_mes on controle_contabil_extratos(empresa_id, mes);
create index idx_cce_conta on controle_contabil_extratos(conta_bancaria_id);
create index idx_cce_mes on controle_contabil_extratos(mes);

alter table controle_contabil_extratos enable row level security;
create policy cce_select on controle_contabil_extratos
  for select using (public.is_active_user());
create policy cce_write on controle_contabil_extratos
  for all using (public.is_active_user())
  with check (public.is_active_user());

create table extratos_arquivos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references empresas(id) on delete cascade,
  conta_bancaria_id uuid not null references contas_bancarias(id) on delete cascade,
  mes text not null,
  arquivo_path text not null,
  arquivo_nome text not null,
  tamanho_bytes bigint,
  uploaded_por_id uuid references usuarios(id) on delete set null,
  uploaded_por_nome text,
  uploaded_em timestamptz not null default now()
);

create index idx_extratos_empresa on extratos_arquivos(empresa_id);
create index idx_extratos_conta_mes on extratos_arquivos(conta_bancaria_id, mes);
create index idx_extratos_empresa_mes on extratos_arquivos(empresa_id, mes);

alter table extratos_arquivos enable row level security;
create policy extratos_arquivos_select on extratos_arquivos
  for select using (public.is_active_user());
create policy extratos_arquivos_write on extratos_arquivos
  for all using (public.is_active_user())
  with check (public.is_active_user());

create trigger trg_contas_bancarias_atualizado
  before update on contas_bancarias
  for each row execute function set_atualizado_em();

create trigger trg_cce_atualizado
  before update on controle_contabil_extratos
  for each row execute function set_atualizado_em();

-- =================================================================
-- BLOCO 10: ARQUIVO ANOTAÇÕES
-- =================================================================

create table arquivo_anotacoes (
  id uuid primary key default gen_random_uuid(),
  arquivo_path text not null,
  contexto text not null check (contexto in ('extrato', 'documento')),
  empresa_id uuid not null references empresas(id) on delete cascade,
  tipo text not null check (tipo in ('highlight', 'note', 'underline', 'strikethrough')),
  pagina int not null default 1,
  conteudo jsonb not null,
  comentario text,
  cor text not null default '#FFEB3B',
  criado_por_id uuid references usuarios(id) on delete set null,
  criado_por_nome text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index idx_arquivo_anotacoes_path on arquivo_anotacoes(arquivo_path);
create index idx_arquivo_anotacoes_empresa on arquivo_anotacoes(empresa_id);
create index idx_arquivo_anotacoes_path_pagina on arquivo_anotacoes(arquivo_path, pagina);

create trigger trg_arquivo_anotacoes_atualizado
  before update on arquivo_anotacoes
  for each row execute function set_atualizado_em();

alter table arquivo_anotacoes enable row level security;
create policy arquivo_anotacoes_select on arquivo_anotacoes
  for select using (public.is_active_user());
create policy arquivo_anotacoes_write on arquivo_anotacoes
  for all using (public.can_access_empresa(empresa_id))
  with check (public.can_access_empresa(empresa_id));

-- =================================================================
-- BLOCO 11: EMAILS DO CLIENTE
-- =================================================================

create table empresa_emails_cliente (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references empresas(id) on delete cascade,
  email text not null,
  rotulo text,
  principal boolean not null default false,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (empresa_id, email)
);

create index idx_empresa_emails_empresa on empresa_emails_cliente (empresa_id);
create index idx_empresa_emails_ativo on empresa_emails_cliente (empresa_id, ativo);

create trigger trg_empresa_emails_atualizado
  before update on empresa_emails_cliente
  for each row execute function set_atualizado_em();

alter table empresa_emails_cliente enable row level security;
create policy empresa_emails_select on empresa_emails_cliente
  for select using (public.is_active_user());
create policy empresa_emails_write on empresa_emails_cliente
  for all using (public.is_manager())
  with check (public.is_manager());

-- =================================================================
-- BLOCO 12: OBRIGAÇÕES HABILITADAS POR EMPRESA
-- =================================================================

create table empresa_obrigacoes_habilitadas (
  empresa_id uuid not null references empresas(id) on delete cascade,
  obrigacao text not null,
  habilitada boolean not null default true,
  habilitada_por_id uuid references usuarios(id) on delete set null,
  habilitada_por_nome text,
  habilitada_em timestamptz not null default now(),
  primary key (empresa_id, obrigacao)
);

create index idx_emp_obrig_hab_empresa on empresa_obrigacoes_habilitadas (empresa_id);

alter table empresa_obrigacoes_habilitadas enable row level security;
create policy emp_obrig_hab_select on empresa_obrigacoes_habilitadas
  for select using (public.is_active_user());
create policy emp_obrig_hab_write on empresa_obrigacoes_habilitadas
  for all using (public.can_access_empresa(empresa_id))
  with check (public.can_access_empresa(empresa_id));

-- =================================================================
-- BLOCO 13: GMAIL OAUTH TOKENS
-- =================================================================

create table usuario_gmail_tokens (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references usuarios(id) on delete cascade,
  email text not null,
  refresh_token_enc text not null,
  scope text not null,
  token_type text,
  expiry_date bigint,
  revoked boolean not null default false,
  last_used_at timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (usuario_id)
);

create index idx_usuario_gmail_tokens_email on usuario_gmail_tokens(email);

alter table usuario_gmail_tokens enable row level security;
create policy usuario_gmail_tokens_select on usuario_gmail_tokens
  for select using (auth.uid() = usuario_id);
create policy usuario_gmail_tokens_insert on usuario_gmail_tokens
  for insert with check (auth.uid() = usuario_id);
create policy usuario_gmail_tokens_update on usuario_gmail_tokens
  for update using (auth.uid() = usuario_id) with check (auth.uid() = usuario_id);
create policy usuario_gmail_tokens_delete on usuario_gmail_tokens
  for delete using (auth.uid() = usuario_id);

-- =================================================================
-- BLOCO 14: ÍNDICES NAS FKs DE USUARIOS (otimização)
-- =================================================================

create index idx_responsaveis_usuario on public.responsaveis(usuario_id);
create index idx_observacoes_autor on public.observacoes(autor_id);
create index idx_logs_user on public.logs(user_id);
create index idx_logs_deleted_by on public.logs(deleted_by_id);
create index idx_lixeira_excluido_por on public.lixeira(excluido_por_id);
create index idx_notificacoes_autor on public.notificacoes(autor_id);
create index idx_documentos_criado_por on public.documentos(criado_por_id);
create index idx_checklist_fiscal_concluido_por on public.checklist_fiscal(concluido_por_id);
create index idx_tarefas_concluida_por on public.obrigacao_tarefas(concluida_por_id);
create index idx_obrigacao_envios_enviado_por on public.obrigacao_envios(enviado_por_id);
create index idx_usuario_gmail_tokens_usuario on public.usuario_gmail_tokens(usuario_id);
create index idx_cce_marcado_por on public.controle_contabil_extratos(marcado_por_id);
create index idx_extratos_arquivos_uploaded_por on public.extratos_arquivos(uploaded_por_id);
create index idx_arquivo_anotacoes_criado_por on public.arquivo_anotacoes(criado_por_id);

-- =================================================================
-- FIM
-- Próximo passo: criar usuário admin via Supabase Auth Dashboard
-- =================================================================
