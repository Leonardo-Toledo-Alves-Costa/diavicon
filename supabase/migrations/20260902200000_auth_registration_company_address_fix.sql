-- Self-registration owns two address records for a company creator:
-- p_address is the person's address and p_company.endereco is the company's
-- commercial address. The function remains service-role-only and transactional.
begin;

create or replace function public.complete_self_registration(
  p_user_id uuid,
  p_email text,
  p_profile_type text,
  p_profile jsonb,
  p_address jsonb,
  p_company jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, auth
as $$
declare
  v_auth_email text;
  v_confirmed_at timestamptz;
  v_existing_empresa_id uuid;
  v_existing_endereco_id uuid;
  v_existing_convite boolean;
  v_endereco_pessoal_id uuid;
  v_endereco_comercial_id uuid;
  v_empresa_id uuid;
  v_plan_id uuid;
  v_type text;
  v_nome text;
  v_sobrenome text;
  v_celular text;
  v_perfil text;
  v_escolaridade text;
  v_titulo text;
  v_foto_url text;
  v_cnpj text;
  v_digits text;
  v_company_address jsonb;
  v_sum integer;
  v_check integer;
  v_weights integer[];
  i integer;
begin
  if p_user_id is null or p_email is null or p_profile_type is null
     or p_profile is null or p_address is null
     or jsonb_typeof(p_profile) <> 'object'
     or jsonb_typeof(p_address) <> 'object' then
    raise exception using errcode = '22023', message = 'Dados de cadastro inválidos.';
  end if;

  select lower(u.email), u.email_confirmed_at
  into v_auth_email, v_confirmed_at
  from auth.users u
  where u.id = p_user_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'Usuário Auth não encontrado.';
  end if;
  if v_auth_email is distinct from lower(btrim(p_email)) then
    raise exception using errcode = '42501', message = 'O e-mail da sessão não corresponde ao cadastro.';
  end if;
  if v_confirmed_at is null then
    raise exception using errcode = '42501', message = 'Confirme o e-mail antes de concluir o cadastro.';
  end if;

  v_type := lower(btrim(p_profile_type));
  if v_type not in ('academico', 'academic', 'empresa', 'company') then
    raise exception using errcode = '22023', message = 'Tipo de perfil inválido.';
  end if;

  -- Serialize retries for the same Auth account. A completed company retry
  -- returns its existing company without creating another address/company.
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));
  select u.empresa_id, u.endereco_id, u.convite_pendente
  into v_existing_empresa_id, v_existing_endereco_id, v_existing_convite
  from public.usuarios u
  where u.id = p_user_id
  for update;

  if v_existing_convite is true or v_existing_empresa_id is not null then
    if v_type in ('empresa', 'company') and v_existing_empresa_id is not null then
      return jsonb_build_object('status', 'active', 'user_id', p_user_id,
                                'empresa_id', v_existing_empresa_id);
    end if;
    raise exception using errcode = '23505', message = 'Este perfil já está vinculado a uma empresa ou convite.';
  end if;

  v_nome := nullif(btrim(p_profile ->> 'nome'), '');
  v_sobrenome := nullif(btrim(p_profile ->> 'sobrenome'), '');
  v_celular := nullif(btrim(coalesce(p_profile ->> 'celular', p_profile ->> 'telefone')), '');
  v_perfil := nullif(btrim(p_profile ->> 'perfil'), '');
  v_escolaridade := nullif(btrim(p_profile ->> 'escolaridade'), '');
  v_titulo := nullif(btrim(coalesce(p_profile ->> 'titulo_principal', p_profile ->> 'formacao')), '');
  v_foto_url := nullif(btrim(p_profile ->> 'foto_url'), '');
  if v_nome is null or v_sobrenome is null then
    raise exception using errcode = '22023', message = 'Nome e sobrenome são obrigatórios.';
  end if;

  -- The root address is always the person's address.
  if v_existing_endereco_id is null then
    insert into public.enderecos (
      endereco, cidade, estado, cep, bairro, numero, complemento, pais
    ) values (
      nullif(btrim(p_address ->> 'endereco'), ''),
      nullif(btrim(p_address ->> 'cidade'), ''),
      nullif(btrim(p_address ->> 'estado'), ''),
      nullif(btrim(p_address ->> 'cep'), ''),
      nullif(btrim(p_address ->> 'bairro'), ''),
      nullif(btrim(p_address ->> 'numero'), ''),
      nullif(btrim(p_address ->> 'complemento'), ''),
      coalesce(nullif(btrim(p_address ->> 'pais'), ''), 'Brasil')
    ) returning id into v_endereco_pessoal_id;
  else
    v_endereco_pessoal_id := v_existing_endereco_id;
    update public.enderecos
    set endereco = nullif(btrim(p_address ->> 'endereco'), ''),
        cidade = nullif(btrim(p_address ->> 'cidade'), ''),
        estado = nullif(btrim(p_address ->> 'estado'), ''),
        cep = nullif(btrim(p_address ->> 'cep'), ''),
        bairro = nullif(btrim(p_address ->> 'bairro'), ''),
        numero = nullif(btrim(p_address ->> 'numero'), ''),
        complemento = nullif(btrim(p_address ->> 'complemento'), ''),
        pais = coalesce(nullif(btrim(p_address ->> 'pais'), ''), 'Brasil')
    where id = v_endereco_pessoal_id;
  end if;

  if v_type in ('academico', 'academic') then
    if exists (select 1 from public.usuarios where id = p_user_id) then
      update public.usuarios
      set nome = v_nome,
          sobrenome = v_sobrenome,
          email = v_auth_email,
          celular = v_celular,
          perfil = coalesce(v_perfil, 'academico'),
          escolaridade = v_escolaridade,
          titulo_principal = v_titulo,
          foto_url = coalesce(v_foto_url, foto_url),
          endereco_id = v_endereco_pessoal_id,
          ativo = true,
          convite_pendente = false,
          is_admin_empresa = false,
          is_admin = false
      where id = p_user_id;
    else
      insert into public.usuarios (
        id, nome, sobrenome, email, celular, perfil, escolaridade,
        titulo_principal, foto_url, endereco_id, ativo, convite_pendente,
        is_admin_empresa, is_admin
      ) values (
        p_user_id, v_nome, v_sobrenome, v_auth_email, v_celular,
        coalesce(v_perfil, 'academico'), v_escolaridade, v_titulo,
        v_foto_url, v_endereco_pessoal_id, true, false, false, false
      );
    end if;
    return jsonb_build_object('status', 'active', 'user_id', p_user_id, 'empresa_id', null);
  end if;

  if jsonb_typeof(p_company) <> 'object' then
    raise exception using errcode = '22023', message = 'Dados da empresa são obrigatórios.';
  end if;
  v_company_address := p_company -> 'endereco';
  if jsonb_typeof(v_company_address) <> 'object' then
    raise exception using errcode = '22023', message = 'Endereço comercial é obrigatório.';
  end if;
  if nullif(btrim(p_company ->> 'nome'), '') is null
     or nullif(btrim(p_company ->> 'cnpj'), '') is null then
    raise exception using errcode = '22023', message = 'Nome e CNPJ da empresa são obrigatórios.';
  end if;

  -- Defense in depth: validate both CNPJ length/repetition and check digits.
  v_digits := regexp_replace(p_company ->> 'cnpj', '[^0-9]', '', 'g');
  if length(v_digits) <> 14 or v_digits ~ '^(.)\1{13}$' then
    raise exception using errcode = '22023', message = 'CNPJ inválido.';
  end if;
  v_weights := array[5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  v_sum := 0;
  for i in 1..12 loop
    v_sum := v_sum + substr(v_digits, i, 1)::integer * v_weights[i];
  end loop;
  v_check := case when v_sum % 11 < 2 then 0 else 11 - (v_sum % 11) end;
  if v_check <> substr(v_digits, 13, 1)::integer then
    raise exception using errcode = '22023', message = 'CNPJ inválido.';
  end if;
  v_weights := array[6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  v_sum := 0;
  for i in 1..13 loop
    v_sum := v_sum + substr(v_digits, i, 1)::integer * v_weights[i];
  end loop;
  v_check := case when v_sum % 11 < 2 then 0 else 11 - (v_sum % 11) end;
  if v_check <> substr(v_digits, 14, 1)::integer then
    raise exception using errcode = '22023', message = 'CNPJ inválido.';
  end if;
  v_cnpj := substr(v_digits, 1, 2) || '.' || substr(v_digits, 3, 3) || '.' ||
            substr(v_digits, 6, 3) || '/' || substr(v_digits, 9, 4) || '-' || substr(v_digits, 13, 2);

  -- A company creator gets a second, commercial address. It is deliberately
  -- never assigned to usuarios.endereco_id.
  insert into public.enderecos (
    endereco, cidade, estado, cep, bairro, numero, complemento, pais
  ) values (
    nullif(btrim(v_company_address ->> 'endereco'), ''),
    nullif(btrim(v_company_address ->> 'cidade'), ''),
    nullif(btrim(v_company_address ->> 'estado'), ''),
    nullif(btrim(v_company_address ->> 'cep'), ''),
    nullif(btrim(v_company_address ->> 'bairro'), ''),
    nullif(btrim(v_company_address ->> 'numero'), ''),
    nullif(btrim(v_company_address ->> 'complemento'), ''),
    coalesce(nullif(btrim(v_company_address ->> 'pais'), ''), 'Brasil')
  ) returning id into v_endereco_comercial_id;

  select id into v_plan_id from public.planos where is_default is true;
  if v_plan_id is null then
    raise exception using errcode = 'P0001', message = 'Plano padrão não configurado.';
  end if;

  insert into public.empresas (
    nome, cnpj, descricao, tipo, ativo, endereco_id, plano_id, tamanho,
    foto_url, site, linkedin, instagram, email_contato, whatsapp, youtube,
    ramo_atuacao, foto_capa, sobre
  ) values (
    nullif(btrim(p_company ->> 'nome'), ''),
    v_cnpj,
    nullif(btrim(p_company ->> 'descricao'), ''),
    coalesce(nullif(btrim(p_company ->> 'tipo'), ''), 'Profissional'),
    true,
    v_endereco_comercial_id,
    v_plan_id,
    nullif(btrim(coalesce(p_company ->> 'tamanho', p_company ->> 'colaboradores')), ''),
    nullif(btrim(p_company ->> 'foto_url'), ''),
    nullif(btrim(p_company ->> 'site'), ''),
    nullif(btrim(p_company ->> 'linkedin'), ''),
    nullif(btrim(p_company ->> 'instagram'), ''),
    nullif(btrim(p_company ->> 'email_contato'), ''),
    nullif(btrim(p_company ->> 'whatsapp'), ''),
    nullif(btrim(p_company ->> 'youtube'), ''),
    nullif(btrim(p_company ->> 'ramo_atuacao'), ''),
    nullif(btrim(p_company ->> 'foto_capa'), ''),
    nullif(btrim(p_company ->> 'sobre'), '')
  ) returning id into v_empresa_id;

  if exists (select 1 from public.usuarios where id = p_user_id) then
    update public.usuarios
    set nome = v_nome,
        sobrenome = v_sobrenome,
        email = v_auth_email,
        celular = v_celular,
        perfil = coalesce(v_perfil, 'empresa'),
        escolaridade = v_escolaridade,
        titulo_principal = v_titulo,
        foto_url = coalesce(v_foto_url, foto_url),
        endereco_id = v_endereco_pessoal_id,
        empresa_id = v_empresa_id,
        ativo = true,
        convite_pendente = false,
        is_admin_empresa = true,
        is_admin = false,
        cargo = coalesce(nullif(btrim(p_profile ->> 'cargo'), ''), cargo)
    where id = p_user_id;
  else
    insert into public.usuarios (
      id, nome, sobrenome, email, celular, perfil, escolaridade,
      titulo_principal, foto_url, endereco_id, empresa_id, ativo,
      convite_pendente, is_admin_empresa, is_admin, cargo
    ) values (
      p_user_id, v_nome, v_sobrenome, v_auth_email, v_celular,
      coalesce(v_perfil, 'empresa'), v_escolaridade, v_titulo, v_foto_url,
      v_endereco_pessoal_id, v_empresa_id, true, false, true, false,
      nullif(btrim(p_profile ->> 'cargo'), '')
    );
  end if;

  return jsonb_build_object('status', 'active', 'user_id', p_user_id,
                            'empresa_id', v_empresa_id);
end;
$$;

revoke all on function public.complete_self_registration(uuid, text, text, jsonb, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.complete_self_registration(uuid, text, text, jsonb, jsonb, jsonb)
  to service_role;

commit;
