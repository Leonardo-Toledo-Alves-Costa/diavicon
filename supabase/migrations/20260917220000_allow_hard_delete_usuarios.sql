-- Prerequisito pro hard-delete de colaborador (excluir definitivamente):
-- excluir uma linha de `usuarios` hoje falharia com violação de FK se esse
-- usuário tiver autorado algum post no feed ou criado algum convite de
-- cliente — ambas as colunas são opcionais e não são "dados do usuário",
-- então SET NULL preserva o conteúdo (post/convite) e só desvincula o autor,
-- em vez de travar a exclusão ou apagar histórico de terceiros.

begin;

alter table public.feed_posts
  drop constraint feed_posts_usuario_id_fkey,
  add constraint feed_posts_usuario_id_fkey
    foreign key (usuario_id) references public.usuarios(id) on delete set null;

alter table public.projeto_convites_cliente
  drop constraint projeto_convites_cliente_criado_por_fkey,
  add constraint projeto_convites_cliente_criado_por_fkey
    foreign key (criado_por) references public.usuarios(id) on delete set null;

commit;
