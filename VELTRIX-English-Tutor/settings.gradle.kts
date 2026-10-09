pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "VeltrixEnglishTutor"
include(":app")
// Android inference module from the OFFICIAL ggml-org/llama.cpp example.
// Run scripts/bootstrap_llama.sh (or .ps1) before Gradle sync.
val officialLlamaLib = file("vendor/llama.cpp/examples/llama.android/lib")
if (officialLlamaLib.exists()) {
    include(":lib")
    project(":lib").projectDir = officialLlamaLib
} else {
    throw GradleException("Missing official inference library. Run scripts/bootstrap_llama.sh or scripts/bootstrap_llama.ps1 before Gradle.")
}
