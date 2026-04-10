import 'dart:html' as html;

void downloadFile(String url, String fileName) {
  html.AnchorElement anchorElement = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..target = 'blank';
  anchorElement.click();
}
