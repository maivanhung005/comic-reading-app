package com.comicreading.ai;
import org.springframework.stereotype.Service;
import java.util.Map;
@Service
public class TTSService {
    public Map<String,Object> synthesizeSpeechMetadata(String text, String lang, double speed) {
        return Map.of("text", text == null ? "" : text, "language", lang == null ? "vi-VN" : lang,
                      "speed", speed, "engine", "FlutterTTS / Google TTS Vietnamese");
    }
}
