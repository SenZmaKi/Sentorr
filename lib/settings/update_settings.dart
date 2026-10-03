class UpdateSettings {
  const UpdateSettings({this.automaticallyDownload = true});
  final bool automaticallyDownload;
  UpdateSettings copyWith({bool? automaticallyDownload}) => UpdateSettings(
    automaticallyDownload: automaticallyDownload ?? this.automaticallyDownload,
  );
  factory UpdateSettings.fromJson(Map<String, dynamic> json) => UpdateSettings(
    automaticallyDownload: json['automaticallyDownload'] != false,
  );
  Map<String, dynamic> toJson() => {
    'automaticallyDownload': automaticallyDownload,
  };
}
