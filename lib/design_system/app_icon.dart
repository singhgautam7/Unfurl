import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';

/// Material Symbols Rounded glyphs used by the app. Codepoints come from
/// `assets/fonts/material_symbols/MaterialSymbolsRounded.codepoints`; add a
/// line here for each new glyph so release builds keep it.
abstract final class AppIcons {
  static const String _family = 'Material Symbols Rounded';

  static const IconData home = IconData(0xe9b2, fontFamily: _family); // home
  static const IconData library = IconData(0xf53e, fontFamily: _family); // book_2
  static const IconData notes = IconData(0xe6d1, fontFamily: _family); // ink_highlighter
  static const IconData more = IconData(0xe429, fontFamily: _family); // tune
  static const IconData tune = IconData(0xe429, fontFamily: _family); // tune
  static const IconData fileOpen = IconData(0xeaf3, fontFamily: _family); // file_open
  static const IconData moreHoriz = IconData(0xe5d3, fontFamily: _family); // more_horiz
  static const IconData moreVert = IconData(0xe5d4, fontFamily: _family); // more_vert
  static const IconData back = IconData(0xe5c4, fontFamily: _family); // arrow_back
  static const IconData close = IconData(0xe5cd, fontFamily: _family); // close
  static const IconData search = IconData(0xef7a, fontFamily: _family); // search
  static const IconData chevronRight = IconData(0xe5cc, fontFamily: _family); // chevron_right
  static const IconData check = IconData(0xe668, fontFamily: _family); // check
  static const IconData folder = IconData(0xe2c7, fontFamily: _family); // folder
  static const IconData folderOpen = IconData(0xe2c8, fontFamily: _family); // folder_open
  static const IconData folderOff = IconData(0xeb83, fontFamily: _family); // folder_off
  static const IconData createNewFolder = IconData(0xe2cc, fontFamily: _family); // create_new_folder
  static const IconData info = IconData(0xe88e, fontFamily: _family); // info
  static const IconData license = IconData(0xeb04, fontFamily: _family); // license
  static const IconData shield = IconData(0xe9e0, fontFamily: _family); // shield
  static const IconData pdf = IconData(0xe415, fontFamily: _family); // picture_as_pdf
  static const IconData book = IconData(0xea19, fontFamily: _family); // menu_book
  static const IconData description = IconData(0xe873, fontFamily: _family); // description
  static const IconData slideshow = IconData(0xe41b, fontFamily: _family); // slideshow
  static const IconData tableView = IconData(0xf1be, fontFamily: _family); // table_view
  static const IconData article = IconData(0xef42, fontFamily: _family); // article
  static const IconData notesText = IconData(0xe26c, fontFamily: _family); // notes
  static const IconData image = IconData(0xe3f4, fontFamily: _family); // image
  static const IconData viewList = IconData(0xe8ef, fontFamily: _family); // view_list
  static const IconData gridView = IconData(0xe9b0, fontFamily: _family); // grid_view
  static const IconData schedule = IconData(0xefd6, fontFamily: _family); // schedule
  static const IconData sortByAlpha = IconData(0xe053, fontFamily: _family); // sort_by_alpha
  static const IconData donutLarge = IconData(0xe917, fontFamily: _family); // donut_large
  static const IconData straighten = IconData(0xe41c, fontFamily: _family); // straighten
  static const IconData visibility = IconData(0xe8f4, fontFamily: _family); // visibility
  static const IconData visibilityOff = IconData(0xe8f5, fontFamily: _family); // visibility_off
  static const IconData accountTree = IconData(0xe97a, fontFamily: _family); // account_tree
  static const IconData subdirectory = IconData(0xe5da, fontFamily: _family); // subdirectory_arrow_right
  static const IconData expandMore = IconData(0xe5cf, fontFamily: _family); // expand_more
  static const IconData expandLess = IconData(0xe5ce, fontFamily: _family); // expand_less
  static const IconData arrowForward = IconData(0xe5c8, fontFamily: _family); // arrow_forward
  static const IconData taskAlt = IconData(0xe2e6, fontFamily: _family); // task_alt
  static const IconData removeCircle = IconData(0xf08f, fontFamily: _family); // remove_circle
  static const IconData openInNew = IconData(0xe89e, fontFamily: _family); // open_in_new
  static const IconData folderZip = IconData(0xeb2c, fontFamily: _family); // folder_zip
  static const IconData code = IconData(0xe86f, fontFamily: _family); // code
  static const IconData sort = IconData(0xe164, fontFamily: _family); // sort
  static const IconData doneAll = IconData(0xe877, fontFamily: _family); // done_all
  static const IconData bookmark = IconData(0xe8e7, fontFamily: _family); // bookmark
  static const IconData bookmarkAdd = IconData(0xe598, fontFamily: _family); // bookmark_add
  static const IconData bookmarkRemove = IconData(0xe59a, fontFamily: _family); // bookmark_remove
  static const IconData editNote = IconData(0xe745, fontFamily: _family); // edit_note
  static const IconData toc = IconData(0xe8de, fontFamily: _family); // toc
  static const IconData crop = IconData(0xe3be, fontFamily: _family); // crop
  static const IconData arrowUp = IconData(0xe316, fontFamily: _family); // keyboard_arrow_up
  static const IconData arrowDown = IconData(0xe313, fontFamily: _family); // keyboard_arrow_down
  static const IconData lock = IconData(0xe899, fontFamily: _family); // lock
  static const IconData wrapText = IconData(0xe25b, fontFamily: _family); // wrap_text
  static const IconData textFields = IconData(0xe262, fontFamily: _family); // text_fields
  static const IconData headphones = IconData(0xf01f, fontFamily: _family); // headphones
  static const IconData documentScanner = IconData(0xe5fa, fontFamily: _family); // document_scanner
  static const IconData copy = IconData(0xe14d, fontFamily: _family); // content_copy
  static const IconData readAloud = IconData(0xe91f, fontFamily: _family); // record_voice_over
  static const IconData volumeUp = IconData(0xe050, fontFamily: _family); // volume_up
  static const IconData shop = IconData(0xe8c9, fontFamily: _family); // shop
  static const IconData skipPrevious = IconData(0xe045, fontFamily: _family); // skip_previous
  static const IconData skipNext = IconData(0xe044, fontFamily: _family); // skip_next
  static const IconData play = IconData(0xe037, fontFamily: _family); // play_arrow
  static const IconData pause = IconData(0xe034, fontFamily: _family); // pause
  static const IconData radioOn = IconData(0xe837, fontFamily: _family); // radio_button_checked
  static const IconData radioOff = IconData(0xe836, fontFamily: _family); // radio_button_unchecked
  static const IconData playCircle = IconData(0xe1c4, fontFamily: _family); // play_circle
  static const IconData settings = IconData(0xe8b8, fontFamily: _family); // settings
  static const IconData share = IconData(0xe6b8, fontFamily: _family); // ios_share
  static const IconData swapVert = IconData(0xe8d5, fontFamily: _family); // swap_vert
  static const IconData swapHoriz = IconData(0xe8d4, fontFamily: _family); // swap_horiz
  static const IconData brightness = IconData(0xe1ad, fontFamily: _family); // brightness_low
  static const IconData densitySmall = IconData(0xeba8, fontFamily: _family); // density_small
  static const IconData densityMedium = IconData(0xeb9e, fontFamily: _family); // density_medium
  static const IconData densityLarge = IconData(0xeba9, fontFamily: _family); // density_large
  static const IconData alignJustify = IconData(0xe235, fontFamily: _family); // format_align_justify
  static const IconData alignLeft = IconData(0xe236, fontFamily: _family); // format_align_left
  static const IconData rotateRight = IconData(0xe41a, fontFamily: _family); // rotate_right
  static const IconData checkBox = IconData(0xe9de, fontFamily: _family); // check_box
  static const IconData checkBoxBlank = IconData(0xe835, fontFamily: _family); // check_box_outline_blank
  static const IconData systemUpdate = IconData(0xf2cd, fontFamily: _family); // system_update
  static const IconData brokenImage = IconData(0xe3ad, fontFamily: _family); // broken_image
  static const IconData helpCenter = IconData(0xf1c0, fontFamily: _family); // help_center
  static const IconData mail = IconData(0xe159, fontFamily: _family); // mail
  static const IconData palette = IconData(0xe40a, fontFamily: _family); // palette
  static const IconData darkMode = IconData(0xe51c, fontFamily: _family); // dark_mode
  static const IconData star = IconData(0xf09a, fontFamily: _family); // star
  static const IconData apps = IconData(0xe5c3, fontFamily: _family); // apps
  static const IconData person = IconData(0xf0d3, fontFamily: _family); // person
  static const IconData error = IconData(0xf8b6, fontFamily: _family); // error
  static const IconData checkCircle = IconData(0xf0be, fontFamily: _family); // check_circle
  static const IconData key = IconData(0xe73c, fontFamily: _family); // key
  static const IconData privacy = IconData(0xf0dc, fontFamily: _family); // privacy_tip
  static const IconData link = IconData(0xe250, fontFamily: _family); // link
  static const IconData warning = IconData(0xf083, fontFamily: _family); // warning
  static const IconData history = IconData(0xe8b3, fontFamily: _family); // history
  static const IconData translate = IconData(0xe8e2, fontFamily: _family); // translate
  static const IconData formatSize = IconData(0xe245, fontFamily: _family); // format_size
  static const IconData volumeOff = IconData(0xe04f, fontFamily: _family); // volume_off
  static const IconData zoomIn = IconData(0xe8ff, fontFamily: _family); // zoom_in
  static const IconData delete = IconData(0xe92e, fontFamily: _family); // delete
  static const IconData add = IconData(0xe145, fontFamily: _family); // add
  static const IconData touchApp = IconData(0xe913, fontFamily: _family); // touch_app
  static const IconData fitWidth = IconData(0xf779, fontFamily: _family); // fit_width
  static const IconData photo = IconData(0xe693, fontFamily: _family); // photo
}

/// A symbol at the boards' weight (350) and optical size. Every icon in the
/// app goes through this, so the axis values live in one place.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {this.size = IconSpec.size, this.color, this.fill = false, super.key});

  final IconData icon;
  final double size;
  final Color? color;

  /// The filled variant (play, pause on the boards).
  final bool fill;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: size, color: color, weight: IconSpec.weight, fill: fill ? 1 : 0, opticalSize: size);
}
