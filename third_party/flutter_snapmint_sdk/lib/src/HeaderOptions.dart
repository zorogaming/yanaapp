class HeaderOptions {
  final bool enableHeader;
  final bool showTitle;
  final String? title;
  final String? backButtonColor; // hex string like #RRGGBB or #AARRGGBB
  final String? titleColor; // hex string
  final String? headerColor; // hex string

  const HeaderOptions({
    this.enableHeader = false,
    this.showTitle = false,
    this.title,
    this.backButtonColor,
    this.titleColor,
    this.headerColor,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enableHeader': enableHeader,
      'showTitle': showTitle,
      if (title != null) 'title': title,
      if (backButtonColor != null) 'backButtonColor': backButtonColor,
      if (titleColor != null) 'titleColor': titleColor,
      if (headerColor != null) 'headerColor': headerColor,
    };
  }
}


