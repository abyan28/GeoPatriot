# Flutter sudah menyertakan consumer rules sendiri. Flutter engine memanggil
# kelas Play Core (deferred components) secara opsional; aplikasi ini tidak
# memakainya, jadi peringatan R8 untuk kelas tersebut diabaikan.
-dontwarn com.google.android.play.core.**
