# Flutter'ın varsayılan kuralları
-dontwarn io.flutter.embedding.**

# Google Mobile Ads (AdMob) SDK'sı için gerekli kurallar
# Bu kurallar, SDK'nın önemli parçalarının silinmesini engeller ve çökmeyi önler.
-keep public class com.google.android.gms.ads.** {
   public *;
}

-keep public class com.google.ads.** {
   public *;
}

# Google Play Services'in diğer gerekli bileşenleri için kurallar
-keep class * extends java.lang.annotation.Annotation {
    *;
}
-keepattributes *Annotation*

# Bu kural, AdMob'un dahili (internal) sınıflarının bozulmasını engelleyerek
# 'java.lang.VerifyError' çökmesini önler.
-keep class com.google.android.gms.internal.ads.** {
   *;
}