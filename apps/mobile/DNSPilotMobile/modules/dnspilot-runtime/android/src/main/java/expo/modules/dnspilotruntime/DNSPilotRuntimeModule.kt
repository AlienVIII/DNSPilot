package expo.modules.dnspilotruntime

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import java.io.File

class DNSPilotRuntimeModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("DNSPilotRuntime")

    Function("isAvailable") { true }

    AsyncFunction("runAction") { action: String, payloadJson: String ->
      val context = requireNotNull(appContext.reactContext) { "React context is unavailable" }
      val databasePath = File(context.filesDir, "dnspilot.sqlite").absolutePath
      nativeRunAction(action, payloadJson, databasePath)
    }
  }

  companion object {
    init {
      System.loadLibrary("dnspilot_mobile_runtime")
    }

    @JvmStatic
    private external fun nativeRunAction(action: String, payloadJson: String, databasePath: String?): String
  }
}
