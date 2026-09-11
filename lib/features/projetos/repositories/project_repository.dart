import 'dart:io';

import 'package:diavicon/features/projetos/models/projeto_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectRepository {
  ProjectRepository(this._supabase);

  final SupabaseClient _supabase;

  static const _projectSelect = '''
    *,
    prioridade(nome),
    status_projeto(nome),
    empresas!projetos_empresa_gestora_id_fkey(nome, foto_url),
    empresa_cliente:empresas!projetos_empresa_cliente_id_fkey(nome, foto_url),
    projeto_equipe_interna(
      empresa_id,
      usuarios(foto_url)
    )
  ''';

  Future<List<ProjetoModel>> fetchVisibleProjects() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    final userData = await _supabase
        .from('usuarios')
        .select('empresa_id, is_admin_empresa')
        .eq('id', userId)
        .maybeSingle();

    final companyId = userData?['empresa_id']?.toString();
    final isCompanyAdmin = userData?['is_admin_empresa'] == true;
    if (companyId == null || companyId.isEmpty) return const [];

    if (!isCompanyAdmin) {
      final memberships = await _supabase
          .from('projeto_equipe_interna')
          .select('projeto_id')
          .eq('usuario_id', userId)
          .eq('ativo', true);

      final projectIds = (memberships as List)
          .map((item) => (item as Map<String, dynamic>)['projeto_id'])
          .whereType<Object>()
          .map((id) => id.toString())
          .toList();

      if (projectIds.isEmpty) return const [];

      final response = await _supabase
          .from('projetos')
          .select(_projectSelect)
          .eq('projeto_equipe_interna.empresa_id', companyId)
          .eq('projeto_equipe_interna.ativo', true)
          .inFilter('id', projectIds);

      return _mapProjects(response, companyId);
    }

    final collaborations = await _supabase
        .from('projeto_empresas_colaboradoras')
        .select('projeto_id')
        .eq('empresa_id', companyId)
        .eq('status', 'aceito');

    final collaborationIds = (collaborations as List)
        .map((item) => (item as Map<String, dynamic>)['projeto_id'])
        .whereType<Object>()
        .map((id) => id.toString())
        .toList();

    var query = _supabase
        .from('projetos')
        .select(_projectSelect)
        .eq('projeto_equipe_interna.empresa_id', companyId)
        .eq('projeto_equipe_interna.ativo', true);

    final companyFilter = <String>[
      'empresa_gestora_id.eq.$companyId',
      'empresa_cliente_id.eq.$companyId',
      if (collaborationIds.isNotEmpty) 'id.in.(${collaborationIds.join(',')})',
    ].join(',');

    final response = await query.or(companyFilter);
    return _mapProjects(response, companyId);
  }

  Future<String?> fetchCurrentUserCompanyId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final userData = await _supabase
        .from('usuarios')
        .select('empresa_id')
        .eq('id', userId)
        .maybeSingle();

    return userData?['empresa_id']?.toString();
  }

  Future<ProjetoModel> fetchProjectById(String projectId) async {
    final companyId = await fetchCurrentUserCompanyId();
    if (companyId == null) {
      throw StateError('Usuário sem empresa vinculada.');
    }

    final response = await _supabase
        .from('projetos')
        .select(_projectSelect)
        .eq('projeto_equipe_interna.empresa_id', companyId)
        .eq('projeto_equipe_interna.ativo', true)
        .eq('id', projectId)
        .single();

    return ProjetoModel.fromMap(response, minhaEmpresaId: companyId);
  }

  Future<String> createProject({
    required String nome,
    String? empresaClienteId,
    required bool isNovoCliente,
    String? emailNovoCliente,
    String? nomeNovoCliente,
    File? imagemProjeto,
    File? fotoNovoCliente,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão expirada. Faça login novamente.');
    }

    final actor = await _supabase
        .from('usuarios')
        .select('empresa_id')
        .eq('id', userId)
        .single();
    final managerCompanyId = actor['empresa_id']?.toString();
    if (managerCompanyId == null || managerCompanyId.isEmpty) {
      throw StateError('Usuário sem empresa gestora vinculada.');
    }

    _validateProjectDraft(
      nome: nome,
      empresaClienteId: empresaClienteId,
      isNovoCliente: isNovoCliente,
      emailNovoCliente: emailNovoCliente,
      nomeNovoCliente: nomeNovoCliente,
    );

    final uploadedPaths = <String>[];
    try {
      _UploadedProjectImage? projectImage;
      _UploadedProjectImage? clientImage;

      if (imagemProjeto != null) {
        projectImage = await _uploadProjectImage(
          imagemProjeto,
          userId: userId,
          directory: 'capas',
        );
        uploadedPaths.add(projectImage.path);
      }

      if (isNovoCliente && fotoNovoCliente != null) {
        clientImage = await _uploadProjectImage(
          fotoNovoCliente,
          userId: userId,
          directory: 'clientes',
        );
        uploadedPaths.add(clientImage.path);
      }

      // Project creation, team membership, client link/invite and
      // notifications must commit together. The RPC also performs the
      // manager and client-admin checks under the caller's authenticated JWT.
      final response = await _supabase.rpc(
        'create_project',
        params: {
          'p_name': nome.trim(),
          'p_client_company_id': isNovoCliente ? null : empresaClienteId,
          'p_new_client_email': isNovoCliente ? emailNovoCliente!.trim() : null,
          'p_new_client_name': isNovoCliente ? nomeNovoCliente!.trim() : null,
          'p_image_url': projectImage?.path,
          'p_new_client_image_url': clientImage?.path,
        },
      );
      if (response == null || response.toString().isEmpty) {
        throw StateError('O servidor não retornou o projeto criado.');
      }
      return response.toString();
    } catch (error) {
      await _removeUploadedFiles(uploadedPaths);
      rethrow;
    }
  }

  Future<void> updateProject({
    required String projetoId,
    required String nome,
    required String descricao,
    required String statusNomeUI,
    required String prioridadeNomeUI,
    File? novaImagem,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sessão expirada. Faça login novamente.');
    }
    if (nome.trim().isEmpty) {
      throw ArgumentError.value(nome, 'nome', 'Informe o nome do projeto.');
    }
    if (statusNomeUI.trim().isEmpty || prioridadeNomeUI.trim().isEmpty) {
      throw ArgumentError('Informe o status e a prioridade do projeto.');
    }

    _UploadedProjectImage? uploadedImage;
    String? previousImagePath;

    try {
      if (novaImagem != null) {
        final currentProject = await _supabase
            .from('projetos')
            .select('image_url')
            .eq('id', projetoId)
            .maybeSingle();
        if (currentProject == null) {
          throw StateError(
            'Projeto não encontrado ou usuário sem permissão para editá-lo.',
          );
        }
        previousImagePath = _ownedProjectImagePath(
          currentProject['image_url']?.toString(),
          userId,
        );

        uploadedImage = await _uploadProjectImage(
          novaImagem,
          userId: userId,
          directory: 'capas',
        );
      }

      final updated = await _supabase.rpc(
        'update_project',
        params: {
          'p_project_id': projetoId,
          'p_name': nome.trim(),
          'p_description': descricao.trim(),
          'p_status_name': statusNomeUI.trim(),
          'p_priority_name': prioridadeNomeUI.trim(),
          'p_image_url': uploadedImage?.path,
        },
      );
      if (updated == null || updated.toString().isEmpty) {
        throw StateError(
          'Projeto não encontrado ou usuário sem permissão para editá-lo.',
        );
      }

      if (previousImagePath != null &&
          previousImagePath != uploadedImage?.path) {
        await _removeUploadedFiles([previousImagePath]);
      }
    } catch (error) {
      if (uploadedImage != null) {
        await _removeUploadedFiles([uploadedImage.path]);
      }
      rethrow;
    }
  }

  /// Exclui o projeto. Com a migration de `ON DELETE CASCADE` aplicada, isso
  /// já limpa sozinho os vínculos com estruturas (`projeto_estruturas`),
  /// equipe, convites e os pontos de ensaio "avulsos" com `projeto_id`
  /// direto — mas NÃO apaga as estruturas vinculadas em si (isso é uma ação
  /// separada e explícita, ver `EstruturaRepository.excluirEstrutura`).
  Future<void> deleteProject(String projectId) async {
    await _supabase.rpc('delete_project', params: {'p_project_id': projectId});
  }

  List<ProjetoModel> _mapProjects(Object response, String companyId) {
    return (response as List)
        .cast<Map<String, dynamic>>()
        .map((json) => ProjetoModel.fromMap(json, minhaEmpresaId: companyId))
        .toList();
  }

  Future<_UploadedProjectImage> _uploadProjectImage(
    File image, {
    required String userId,
    required String directory,
  }) async {
    final rawExtension = image.path.split('.').last.toLowerCase();
    final extension = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(rawExtension)
        ? rawExtension
        : 'jpg';
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final storagePath = 'users/$userId/$directory/$timestamp.$extension';

    final bucket = _supabase.storage.from('projetos');
    await bucket.upload(storagePath, image);
    return _UploadedProjectImage(path: storagePath);
  }

  Future<void> _removeUploadedFiles(List<String> paths) async {
    if (paths.isEmpty) return;

    try {
      await _supabase.storage.from('projetos').remove(paths);
    } catch (_) {
      // A falha original é mais relevante; a limpeza pode ser repetida no backend.
    }
  }

  String? _ownedProjectImagePath(String? publicUrl, String userId) {
    if (publicUrl == null || publicUrl.isEmpty) return null;

    final uri = Uri.tryParse(publicUrl);
    if (uri == null) return null;

    const marker = <String>['storage', 'v1', 'object', 'public', 'projetos'];
    final segments = uri.pathSegments;
    var markerIndex = -1;
    for (var index = 0; index <= segments.length - marker.length; index++) {
      var matches = true;
      for (var offset = 0; offset < marker.length; offset++) {
        if (segments[index + offset] != marker[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        markerIndex = index;
        break;
      }
    }

    if (markerIndex < 0) return null;
    final objectSegments = segments.skip(markerIndex + marker.length).toList();
    if (objectSegments.length != 4 ||
        objectSegments[0] != 'users' ||
        objectSegments[1] != userId ||
        objectSegments[2] != 'capas' ||
        objectSegments[3].isEmpty) {
      return null;
    }

    final objectPath = objectSegments.join('/');
    final expectedUrl = _supabase.storage
        .from('projetos')
        .getPublicUrl(objectPath);
    return publicUrl == expectedUrl ? objectPath : null;
  }

  static void _validateProjectDraft({
    required String nome,
    required String? empresaClienteId,
    required bool isNovoCliente,
    required String? emailNovoCliente,
    required String? nomeNovoCliente,
  }) {
    if (nome.trim().isEmpty) {
      throw ArgumentError.value(nome, 'nome', 'Informe o nome do projeto.');
    }

    if (isNovoCliente) {
      if ((emailNovoCliente?.trim().isEmpty ?? true) ||
          (nomeNovoCliente?.trim().isEmpty ?? true)) {
        throw ArgumentError('Informe o nome e o e-mail do novo cliente.');
      }
      return;
    }

    if (empresaClienteId == null || empresaClienteId.isEmpty) {
      throw ArgumentError('Selecione um cliente existente.');
    }
  }
}

class _UploadedProjectImage {
  const _UploadedProjectImage({required this.path});

  final String path;
}
