[1mdiff --git a/lib/tools/work_log/pages/task/work_task_detail_page.dart b/lib/tools/work_log/pages/task/work_task_detail_page.dart[m
[1mindex 5da3740..0d4a855 100644[m
[1m--- a/lib/tools/work_log/pages/task/work_task_detail_page.dart[m
[1m+++ b/lib/tools/work_log/pages/task/work_task_detail_page.dart[m
[36m@@ -145,6 +145,7 @@[m [mclass _WorkTaskDetailPageState extends State<WorkTaskDetailPage> {[m
     }[m
 [m
     final totalMinutes = _entries.fold<int>(0, (sum, e) => sum + e.minutes);[m
[32m+[m[32m    final canAddTimeEntry = _canAddTimeEntry(task.status);[m
 [m
     return Stack([m
       children: [[m
[36m@@ -217,24 +218,25 @@[m [mclass _WorkTaskDetailPageState extends State<WorkTaskDetailPage> {[m
                   ),[m
                 ),[m
                 const Spacer(),[m
[31m-                CupertinoButton([m
[31m-                  padding: EdgeInsets.zero,[m
[31m-                  onPressed: _openAddTimeEntry,[m
[31m-                  child: const Text([m
[31m-                    '添加',[m
[31m-                    style: TextStyle([m
[31m-                      fontSize: 14,[m
[31m-                      fontWeight: FontWeight.w600,[m
[31m-                      color: IOS26Theme.primaryColor,[m
[32m+[m[32m                if (canAddTimeEntry)[m
[32m+[m[32m                  CupertinoButton([m
[32m+[m[32m                    padding: EdgeInsets.zero,[m
[32m+[m[32m                    onPressed: _openAddTimeEntry,[m
[32m+[m[32m                    child: const Text([m
[32m+[m[32m                      '添加',[m
[32m+[m[32m                      style: TextStyle([m
[32m+[m[32m                        fontSize: 14,[m
[32m+[m[32m                        fontWeight: FontWeight.w600,[m
[32m+[m[32m                        color: IOS26Theme.primaryColor,[m
[32m+[m[32m                      ),[m
                     ),[m
                   ),[m
[31m-                ),[m
               ],[m
             ),[m
             const SizedBox(height: 8),[m
             if (_entries.isEmpty)[m
               Text([m
[31m-                '暂无工时记录，点击右上角时钟添加',[m
[32m+[m[32m                '暂无工时记录${canAddTimeEntry ? '，点击右上角时钟添加' : ''}',[m
                 style: TextStyle([m
                   fontSize: 15,[m
                   color: IOS26Theme.textSecondary.withValues(alpha: 0.9),[m
[36m@@ -244,7 +246,7 @@[m [mclass _WorkTaskDetailPageState extends State<WorkTaskDetailPage> {[m
               ..._entries.map((e) => _buildTimeEntryItem(e)),[m
           ],[m
         ),[m
[31m-        if (task.status != WorkTaskStatus.done)[m
[32m+[m[32m        if (canAddTimeEntry)[m
           Positioned([m
             left: 20,[m
             right: 20,[m
[36m@@ -398,17 +400,21 @@[m [mclass _WorkTaskDetailPageState extends State<WorkTaskDetailPage> {[m
   }[m
 [m
   void _showMoreOptions() {[m
[32m+[m[32m    final task = _task;[m
[32m+[m[32m    final canAddTimeEntry = task != null && _canAddTimeEntry(task.status);[m
[32m+[m
     showCupertinoModalPopup<void>([m
       context: context,[m
       builder: (ctx) => CupertinoActionSheet([m
         actions: [[m
[31m-          CupertinoActionSheetAction([m
[31m-            onPressed: () {[m
[31m-              Navigator.pop(ctx);[m
[31m-              _openAddTimeEntry();[m
[31m-            },[m
[31m-            child: const Text('添加工时'),[m
[31m-          ),[m
[32m+[m[32m          if (canAddTimeEntry)[m
[32m+[m[32m            CupertinoActionSheetAction([m
[32m+[m[32m              onPressed: () {[m
[32m+[m[32m                Navigator.pop(ctx);[m
[32m+[m[32m                _openAddTimeEntry();[m
[32m+[m[32m              },[m
[32m+[m[32m              child: const Text('添加工时'),[m
[32m+[m[32m            ),[m
           CupertinoActionSheetAction([m
             isDestructiveAction: true,[m
             onPressed: () {[m
[36m@@ -586,6 +592,10 @@[m [mclass _WorkTaskDetailPageState extends State<WorkTaskDetailPage> {[m
     return '${hours.toStringAsFixed(1)}h';[m
   }[m
 [m
[32m+[m[32m  static bool _canAddTimeEntry(WorkTaskStatus status) {[m
[32m+[m[32m    return status != WorkTaskStatus.done && status != WorkTaskStatus.canceled;[m
[32m+[m[32m  }[m
[32m+[m
   static String _statusLabel(WorkTaskStatus status) {[m
     return switch (status) {[m
       WorkTaskStatus.todo => '待办',[m
