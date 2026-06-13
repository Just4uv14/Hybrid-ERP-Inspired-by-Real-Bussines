
//================ Fungsi untuk uploud Laporan dalam bentuk CSV atau PDF ===================

class HtmlElement {
  final List<HtmlElement> children = [];
  final CssStyleDeclaration style = CssStyleDeclaration();
  void click() {}
  HtmlElement createElement(String tag) => AnchorElement();
}

// AnchorElement extends HtmlElement agar createElement bisa return-nya
class AnchorElement extends HtmlElement {
  String href     = '';
  String download = '';
}

class CssStyleDeclaration {
  String display = '';
}

class Blob {
  Blob(List<dynamic> parts, [String? type]);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class HtmlDocument {
  final HtmlElement body = HtmlElement();
  HtmlElement createElement(String tag) => AnchorElement();
}

final HtmlDocument document = HtmlDocument();