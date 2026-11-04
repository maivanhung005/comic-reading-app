package com.comicreading.ai;
public class CosineSimilarity {
    public static double calculate(double[] a, double[] b) {
        if (a == null || b == null || a.length != b.length || a.length == 0) return 0.0;
        double dot=0.0, normA=0.0, normB=0.0;
        for (int i=0; i<a.length; i++) { dot += a[i]*b[i]; normA += a[i]*a[i]; normB += b[i]*b[i]; }
        if (normA == 0.0 || normB == 0.0) return 0.0;
        return dot / (Math.sqrt(normA) * Math.sqrt(normB));
    }
}
