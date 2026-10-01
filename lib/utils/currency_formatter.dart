String formatRupiah(double? price) {
  final value = price != null && price.isFinite ? price : 0.0;
  final digits = value.abs().round().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  return '${value < 0 ? '-' : ''}Rp$grouped';
}
