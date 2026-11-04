const _groups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

/// Bỏ dấu tiếng Việt để tìm "bua an" vẫn ra "bữa ăn".
String normalizeForSearch(String input) {
  var result = input.toLowerCase().trim();
  _groups.forEach((plain, accented) {
    result = result.replaceAll(RegExp('[$accented]'), plain);
  });
  return result;
}

/// Ghép danh sách theo cách nói tiếng Việt: "a, b và c".
String joinVietnamese(List<String> items) {
  if (items.length < 2) return items.join();
  return '${items.sublist(0, items.length - 1).join(', ')} và ${items.last}';
}
