# Multimodal Visual Security Engine (OCR + CLIP)

## System Architecture

```mermaid
graph TD
    Input[Input: Image/Video Frame] --> Split{Parallel Process}

    %% Engine D Logic
    Split --> EngineD[Engine D: Prompt Injection]
    EngineD --> OCR[PaddleOCR: Extract Text]
    OCR --> Norm[Normalization Layer]
    Norm --> ThreatCheck{Threat Dictionary Check}
    ThreatCheck -- Match Found --> RiskHigh[Risk Score: 1.0 - BLOCK]
    ThreatCheck -- No Match --> RiskLow[Risk Score: 0.0 - PASS]

    %% Engine E Logic
    Split --> EngineE[Engine E: Cross-Modal]
    InputAudio[Input: Audio Transcript] --> CLIP_Text[CLIP Text Encoder]
    EngineE --> CLIP_Img[CLIP Image Encoder]
    CLIP_Text --> Cosine[Cosine Similarity Calc]
    CLIP_Img --> Cosine
    Cosine --> Threshold{Is Score < 0.18?}
    Threshold -- Yes --> Mismatch[Status: MISMATCH - Deepfake]
    Threshold -- No --> Match[Status: MATCH - Genuine]
```

**Engine D (Visual Prompt Injection)**  
OCR-based detection. PaddleOCR extracts visible or hidden text (e.g., low-contrast or white-on-white overlays), then a normalization layer de-obfuscates tokens and checks for adversarial commands like "Ignore previous instructions" using a threat dictionary.

**Engine E (Cross-Modal Consistency)**  
Semantic-based (not OCR). CLIP (ViT-B/32) embeds both the video frame and the audio transcript into a shared vector space to verify that the visual context matches the spoken context.

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Run the Visual Engine Test
python -m src.engines.visual_engine
```
