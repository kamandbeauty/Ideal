import 'caption_effect.dart';

/// Persian UI labels for the effect enums. Plain functions (not extensions) so
/// `tools/check-project.py` can prove every enum case has a visible name and
/// that no file imports this library without using it.
String captionAnimationLabel(CaptionAnimation value) {
  switch (value) {
    case CaptionAnimation.none:
      return 'بدون ورود';
    case CaptionAnimation.fade:
      return 'محو شدن';
    case CaptionAnimation.slideUp:
      return 'ورود از پایین';
    case CaptionAnimation.slideDown:
      return 'ورود از بالا';
    case CaptionAnimation.slideLeft:
      return 'ورود از راست';
    case CaptionAnimation.slideRight:
      return 'ورود از چپ';
    case CaptionAnimation.zoomIn:
      return 'بزرگ‌شدن';
    case CaptionAnimation.zoomOut:
      return 'کوچک‌شدن';
    case CaptionAnimation.pop:
      return 'پاپ';
    case CaptionAnimation.bounce:
      return 'پرش';
    case CaptionAnimation.rotate:
      return 'چرخش';
    case CaptionAnimation.blurIn:
      return 'وضوح تدریجی';
    case CaptionAnimation.typewriter:
      return 'ماشین‌تحریر';
    case CaptionAnimation.wordReveal:
      return 'کلمه‌به‌کلمه';
    case CaptionAnimation.elastic:
      return 'کشسانی';
    case CaptionAnimation.shake:
      return 'لرزش';
    case CaptionAnimation.glowPulse:
      return 'درخشش نبضی';
  }
}

String captionExitLabel(CaptionExit value) {
  switch (value) {
    case CaptionExit.none:
      return 'بدون خروج';
    case CaptionExit.fadeOut:
      return 'محو شدن';
    case CaptionExit.zoomOut:
      return 'کوچک‌شدن';
    case CaptionExit.slideDown:
      return 'خروج به پایین';
    case CaptionExit.slideUp:
      return 'خروج به بالا';
    case CaptionExit.zoomIn:
      return 'بزرگ‌شدن';
    case CaptionExit.rotateOut:
      return 'چرخش';
    case CaptionExit.popOut:
      return 'جمع‌شدن';
    case CaptionExit.blurOut:
      return 'محو تدریجی';
  }
}

String captionWordEffectLabel(CaptionWordEffect value) {
  switch (value) {
    case CaptionWordEffect.none:
      return 'ساده';
    case CaptionWordEffect.karaokeFill:
      return 'کاراوکه';
    case CaptionWordEffect.activeColor:
      return 'رنگ کلمه فعال';
    case CaptionWordEffect.activeScale:
      return 'بزرگ‌شدن کلمه';
    case CaptionWordEffect.wordPop:
      return 'پاپ کلمه';
    case CaptionWordEffect.activeBackground:
      return 'هایلایت کلمه';
    case CaptionWordEffect.activeUnderline:
      return 'خط زیر کلمه';
    case CaptionWordEffect.neighborDim:
      return 'تأکید تمرکزی';
  }
}

String captionEasingLabel(CaptionEasing value) => value.label;
