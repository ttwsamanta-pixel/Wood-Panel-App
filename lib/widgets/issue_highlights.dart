import 'package:flutter/material.dart';

class IssueHighlights extends StatefulWidget {
  const IssueHighlights({super.key, required this.points});
  final List<String> points;
  @override
  State<IssueHighlights> createState() => _IssueHighlightsState();
}

class _IssueHighlightsState extends State<IssueHighlights> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('In This Issue', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SizedBox(
            height: 220,
            child: PageView.builder(
              itemCount: widget.points.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (context, i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .045),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: .18)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_stories_outlined, color: color),
                        const Spacer(),
                        Text('${i + 1} / ${widget.points.length}',
                            style: TextStyle(color: color))
                      ]),
                      const SizedBox(height: 16),
                      Expanded(
                          child: SingleChildScrollView(
                              child: Text(widget.points[i],
                                  style: const TextStyle(
                                      fontSize: 16, height: 1.5)))),
                    ]),
              ),
            )),
        const SizedBox(height: 8),
        Center(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < widget.points.length; i++)
            AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 6,
                width: i == index ? 20 : 6,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: i == index ? 1 : .2),
                    borderRadius: BorderRadius.circular(4))),
        ])),
      ]),
    );
  }
}
