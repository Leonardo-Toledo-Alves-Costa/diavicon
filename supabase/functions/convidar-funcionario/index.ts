import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Função para gerar uma senha aleatória forte e amigável
function gerarSenhaProvisoria() {
  const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let senha = "";
  for (let i = 0; i < 8; i++) {
    senha += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return senha + "@1A"; 
}

Deno.serve(async (req) => {
  // Cabeçalhos CORS para o Flutter não ser bloqueado
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  // Responde ao Pre-flight do Flutter
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Cria o cliente Supabase com a chave de ADMIN (ignora regras de segurança)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { email, nome, sobrenome, cargo, empresa_id } = await req.json()
    const senhaProvisoria = gerarSenhaProvisoria()

    // 1. Cria o usuário com poderes de ADMIN
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: senhaProvisoria,
      email_confirm: true 
    })

    if (authError) throw authError

    // 2. Insere os dados na tabela 'usuarios'
    const { error: dbError } = await supabaseAdmin.from('usuarios').insert({
      id: authData.user.id,
      empresa_id: empresa_id,
      nome: nome,
      sobrenome: sobrenome,
      cargo: cargo,
      ativo: false // Nasce inativo!
    })

    if (dbError) throw dbError

    // 3. Devolve sucesso e a senha para o Flutter
    return new Response(
      JSON.stringify({ 
        sucesso: true, 
        senhaProvisoria: senhaProvisoria,
        mensagem: "Usuário criado com sucesso!"
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error: any) {
    return new Response(
      JSON.stringify({ erro: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})