package com.example.tuntun

import ai.onnxruntime.OnnxJavaType
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.TensorInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.FloatBuffer
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val environment by lazy { OrtEnvironment.getEnvironment() }
    private var session: OrtSession? = null
    private var inputName: String? = null
    private var outputName: String? = null
    private var outputSize = 0
    private var loadedSha256: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> executor.execute {
                        runCatching {
                            initialize(
                                call.argument<String>("sha256") ?: error("Missing model checksum"),
                                call.argument<Int>("dimension") ?: error("Missing embedding dimension"),
                            )
                        }.onSuccess(result::success)
                            .onFailure { result.error("MODEL_UNAVAILABLE", "The local image model could not be loaded.", null) }
                    }
                    "embed" -> executor.execute {
                        runCatching {
                            embed(call.argument<FloatArray>("tensor") ?: error("Missing image tensor"))
                        }.onSuccess { result.success(it) }
                            .onFailure { result.error("INFERENCE_FAILED", "Local image recognition failed.", null) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initialize(expectedSha256: String, expectedDimension: Int): Map<String, Any> {
        session?.let {
            check(loadedSha256 == expectedSha256) { "Model checksum changed" }
            check(outputSize == expectedDimension)
            return mapOf("dimension" to outputSize)
        }
        require(expectedSha256.matches(Regex("[0-9a-f]{64}"))) { "Invalid model checksum" }
        val modelFile = File(cacheDir, MODEL_FILE)
        if (!modelFile.isFile || sha256(modelFile) != expectedSha256) {
            modelFile.delete()
            val temporary = File(cacheDir, "$MODEL_FILE.tmp")
            assets.open("flutter_assets/assets/models/$MODEL_FILE").use { input ->
                FileOutputStream(temporary).use { output -> input.copyTo(output) }
            }
            check(sha256(temporary) == expectedSha256) { "Bundled model checksum mismatch" }
            check(temporary.renameTo(modelFile)) { "Could not prepare the local model" }
        }

        val loaded = environment.createSession(modelFile.absolutePath, OrtSession.SessionOptions())
        try {
            val inName = loaded.inputNames.single()
            val inInfo = loaded.inputInfo.getValue(inName).info as TensorInfo
            check(inInfo.type == OnnxJavaType.FLOAT && inInfo.shape.contentEquals(INPUT_SHAPE))
            val outName = loaded.outputNames.single()
            val outInfo = loaded.outputInfo.getValue(outName).info as TensorInfo
            check(outInfo.type == OnnxJavaType.FLOAT && outInfo.shape.size == 2 && outInfo.shape[0] == 1L)
            outputSize = outInfo.shape[1].toInt()
            check(outputSize == expectedDimension && outputSize > 0)
            inputName = inName
            outputName = outName
            loadedSha256 = expectedSha256
            session = loaded
            return mapOf("dimension" to outputSize)
        } catch (error: Throwable) {
            loaded.close()
            throw error
        }
    }

    private fun embed(data: FloatArray): List<Double> {
        require(data.size == INPUT_SIZE && data.all { it.isFinite() }) { "Invalid image tensor" }
        val active = checkNotNull(session) { "Model is not initialized" }
        val name = checkNotNull(inputName)
        val output = checkNotNull(outputName)
        val tensor = OnnxTensor.createTensor(environment, FloatBuffer.wrap(data), INPUT_SHAPE)
        tensor.use {
            active.run(mapOf(name to tensor)).use { results ->
                val vector = results.get(output).orElseThrow() as OnnxTensor
                vector.use {
                    val values = FloatArray(outputSize)
                    it.floatBuffer.get(values)
                    check(values.all { it.isFinite() } && values.any { value -> value != 0f })
                    return values.map { it.toDouble() }
                }
            }
        }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(1024 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    override fun onDestroy() {
        session?.close()
        executor.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "com.tunton/vision"
        private const val MODEL_FILE = "openclip_vit_b32_laion2b_int8.onnx"
        private const val INPUT_SIZE = 3 * 224 * 224
        private val INPUT_SHAPE = longArrayOf(1, 3, 224, 224)
    }
}
