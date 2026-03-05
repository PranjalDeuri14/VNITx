import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

/// A card widget that renders a Map<String, dynamic> as formatted JSON.
/// Colour-coded by verdict/risk score.
class AnalysisResultCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String? title;

  const AnalysisResultCard({super.key, required this.data, this.title});

  @override
  State<AnalysisResultCard> createState() => _AnalysisResultCardState();
}

class _AnalysisResultCardState extends State<AnalysisResultCard> {
  bool _expanded = true;

  Color get _accentColor {
    final verdict = widget.data['verdict']?.toString().toLowerCase() ??
        widget.data['prediction']?.toString().toLowerCase() ?? '';
    final score = _riskScore;
    if (verdict.contains('ai') || verdict.contains('deepfake') || score > 0.7) {
      return AppTheme.error;
    } else if (score > 0.4) {
      return AppTheme.warning;
    } else if (verdict.contains('human') || verdict.contains('real')) {
      return AppTheme.success;
    }
    return AppTheme.accent;
  }

  double get _riskScore {
    final keys = ['final_score', 'confidence', 'probability', 'score', 'risk_score'];
    for (final k in keys) {
      final v = widget.data[k];
      if (v is num) return v.toDouble();
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(widget.data);
    final score = _riskScore;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title ?? 'Analysis Result',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (score > 0) ...[
                    _ScoreBadge(score: score, color: _accentColor),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Result summary chips
          if (widget.data.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, runSpacing: 6, children: _buildSummaryChips()),
            ),
            const SizedBox(height: 8),
          ],
          // Expanded JSON view
          if (_expanded) ...[
            const Divider(height: 1),
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      prettyJson,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    color: AppTheme.textSecondary,
                    tooltip: 'Copy JSON',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: prettyJson));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSummaryChips() {
    final chips = <Widget>[];
    final priority = ['verdict', 'prediction', 'status', 'label', 'confidence', 'final_score', 'probability'];
    for (final key in priority) {
      if (widget.data.containsKey(key)) {
        final val = widget.data[key];
        if (val != null) {
          chips.add(_buildChip(key, val.toString()));
        }
      }
    }
    return chips;
  }

  Widget _buildChip(String label, String value) {
    return Chip(
      label: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  final Color color;
  const _ScoreBadge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '${(score * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
