import 'dart:convert';
import 'package:github/github.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;

class Server {
  String name = "";
  String address = "";
  Server({required this.name, required this.address});
  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(name: json['name'], address: json['address']);
  }
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Server &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}

Future<RepositoryContents> listFilesInRepo(
    GitHub github, String owner, String repo,
    [String? path]) async {
  RepositorySlug slug = RepositorySlug(owner, repo);
  return await github.repositories.getContents(slug, path ?? '');
}

Future<Map<String, dynamic>?> fetchJsonFromRepo(
    GitHub github, String owner, String repo, String path) async {
  RepositorySlug slug = RepositorySlug(owner, repo);
  RepositoryContents contents =
      await github.repositories.getContents(slug, path);
  dev.log(contents.file?.text ?? "null...", name: "github");
  return jsonDecode(contents.file?.text ?? "");
}

Future<List<Server>> getServers() async {
  dev.log("Getting servers...");
  final github = GitHub(auth: const Authentication.anonymous());

  var file = await fetchJsonFromRepo(
      github, 'panthuncia', 'sailbot_servers', 'servers.json');
  var list = file?['servers'] as List;
  List<Server> serverList = list.map((i) => Server.fromJson(i)).toList();

  return serverList;
}

final serverListProvider = FutureProvider<List<Server>>((ref) async {
  final serverListAsyncValue = getServers();
  return serverListAsyncValue;
});
