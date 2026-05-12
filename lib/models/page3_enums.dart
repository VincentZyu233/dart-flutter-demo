import 'package:flutter/material.dart';

enum LayoutMode { grid, masonry, list }
enum SortMode { updated, stars, name }

enum DensityMode {
  five,
  four,
  three,
  two,
  one;

  static DensityMode fromColumnCount(int col) => switch (col) {
        5 => DensityMode.five,
        4 => DensityMode.four,
        3 => DensityMode.three,
        2 => DensityMode.two,
        _ => DensityMode.one,
      };

  int get columnCount => switch (this) {
        DensityMode.five => 5,
        DensityMode.four => 4,
        DensityMode.three => 3,
        DensityMode.two => 2,
        DensityMode.one => 1,
      };

  double get gap => switch (this) {
        DensityMode.five || DensityMode.four => 10,
        DensityMode.three => 14,
        DensityMode.two || DensityMode.one => 18,
      };

  EdgeInsets get cardPadding => switch (this) {
        DensityMode.five || DensityMode.four => const EdgeInsets.all(10),
        DensityMode.three => const EdgeInsets.all(14),
        DensityMode.two || DensityMode.one => const EdgeInsets.all(18),
      };

  double get cardRadius => switch (this) {
        DensityMode.five || DensityMode.four => 12,
        DensityMode.three => 16,
        DensityMode.two || DensityMode.one => 20,
      };
}
