export type ToolFieldType = 'text' | 'textarea' | 'number' | 'boolean' | 'date' | 'datetime' | 'json';

export type ToolSectionMode = 'list' | 'single';

export interface ToolFieldConfig {
  key: string;
  label: string;
  type: ToolFieldType;
  placeholder?: string;
  readOnly?: boolean;
  defaultValue?: unknown;
  sensitive?: boolean;
}

export interface ToolSectionConfig {
  key: string;
  label: string;
  description: string;
  idKey?: string;
  mode?: ToolSectionMode;
  readOnly?: boolean;
  fields?: ToolFieldConfig[];
}

export interface ToolConfig {
  id: string;
  name: string;
  description: string;
  accentClassName: string;
  sections: ToolSectionConfig[];
}

const toolConfigs: Record<string, ToolConfig> = {
  work_log: {
    id: 'work_log',
    name: '工作记录',
    description: '管理任务、工时和操作留痕。',
    accentClassName: 'from-brand-500/25 via-brand-500/5 to-white',
    sections: [
      {
        key: 'tasks',
        label: '任务',
        description: '维护任务标题、状态、排期和预估工时。',
        idKey: 'id',
        fields: [
          { key: 'id', label: 'ID', type: 'number' },
          { key: 'title', label: '标题', type: 'text', placeholder: '如：整理周报' },
          { key: 'description', label: '描述', type: 'textarea' },
          { key: 'status', label: '状态', type: 'number' },
          { key: 'estimated_minutes', label: '预估分钟', type: 'number' },
          { key: 'is_pinned', label: '置顶', type: 'boolean' },
          { key: 'sort_index', label: '排序', type: 'number' },
          { key: 'created_at', label: '创建时间', type: 'datetime' },
          { key: 'updated_at', label: '更新时间', type: 'datetime' },
        ],
      },
      {
        key: 'time_entries',
        label: '工时记录',
        description: '维护工时内容、时长和所属任务。',
        idKey: 'id',
        fields: [
          { key: 'id', label: 'ID', type: 'number' },
          { key: 'task_id', label: '任务', type: 'number' },
          { key: 'work_date', label: '工作日期', type: 'date' },
          { key: 'minutes', label: '工时分钟', type: 'number' },
          { key: 'content', label: '内容', type: 'textarea' },
          { key: 'created_at', label: '创建时间', type: 'datetime' },
          { key: 'updated_at', label: '更新时间', type: 'datetime' },
        ],
      },
      {
        key: 'task_tags',
        label: '任务标签',
        description: '维护任务与标签的关联关系。',
        fields: [
          { key: 'task_id', label: '任务', type: 'number' },
          { key: 'tag_id', label: '归属标签', type: 'number' },
        ],
      },
      {
        key: 'operation_logs',
        label: '操作日志',
        description: '用于审计和追溯，默认只读。',
        readOnly: true,
        fields: [
          { key: 'id', label: 'ID', type: 'number' },
          { key: 'operation_type', label: '操作类型', type: 'number' },
          { key: 'target_type', label: '目标类型', type: 'number' },
          { key: 'target_id', label: '目标对象', type: 'number' },
          { key: 'target_title', label: '目标标题', type: 'text' },
          { key: 'summary', label: '摘要', type: 'textarea' },
          { key: 'before_snapshot', label: '变更前', type: 'json' },
          { key: 'after_snapshot', label: '变更后', type: 'json' },
          { key: 'created_at', label: '创建时间', type: 'datetime' },
        ],
      },
    ],
  },
  stockpile_assistant: {
    id: 'stockpile_assistant',
    name: '囤货助手',
    description: '管理库存、消耗与补货提醒。',
    accentClassName: 'from-emerald-400/25 via-emerald-300/5 to-white',
    sections: [
      {
        key: 'items',
        label: '库存项',
        description: '管理库存名称、位置、数量和到期时间。',
        idKey: 'id',
        fields: [
          { key: 'id', label: 'ID', type: 'number' },
          { key: 'name', label: '名称', type: 'text' },
          { key: 'location', label: '位置', type: 'text' },
          { key: 'unit', label: '单位', type: 'text' },
          { key: 'total_quantity', label: '总量', type: 'number' },
          { key: 'remaining_quantity', label: '剩余量', type: 'number' },
          { key: 'purchase_date', label: '购买日期', type: 'date' },
          { key: 'expiry_date', label: '到期日期', type: 'date' },
          { key: 'remind_days', label: '提醒天数', type: 'number' },
          { key: 'restock_remind_date', label: '补货提醒日期', type: 'date' },
          { key: 'restock_remind_quantity', label: '补货阈值', type: 'number' },
          { key: 'note', label: '备注', type: 'textarea' },
          { key: 'created_at', label: '创建时间', type: 'datetime' },
          { key: 'updated_at', label: '更新时间', type: 'datetime' },
        ],
      },
      {
        key: 'consumptions',
        label: '消耗记录',
        description: '记录每次消耗数量与方式。',
        idKey: 'id',
        fields: [
          { key: 'id', label: 'ID', type: 'number' },
          { key: 'item_id', label: '库存项', type: 'number' },
          { key: 'quantity', label: '消耗数量', type: 'number' },
          { key: 'method', label: '方式', type: 'text' },
          { key: 'consumed_at', label: '消耗时间', type: 'datetime' },
          { key: 'note', label: '备注', type: 'textarea' },
          { key: 'created_at', label: '创建时间', type: 'datetime' },
        ],
      },
      {
        key: 'item_tags',
        label: '库存标签',
        description: '维护库存与标签的映射。',
        fields: [
          { key: 'item_id', label: '库存项', type: 'number' },
          { key: 'tag_id', label: '标签', type: 'number' },
        ],
      },
    ],
  },
  overcooked_kitchen: {
    id: 'overcooked_kitchen',
    name: '胡闹厨房',
    description: '管理菜谱、想做清单与用餐计划。',
    accentClassName: 'from-orange-400/25 via-orange-300/5 to-white',
    sections: [
      {
        key: 'recipes',
        label: '菜谱',
        description: '维护菜谱基础信息。',
        idKey: 'id',
        fields: [
          { key: 'id', label: 'ID', type: 'number' },
          { key: 'name', label: '名称', type: 'text' },
          { key: 'cover_image_key', label: '封面 Key', type: 'text' },
          { key: 'type_tag_id', label: '菜品风格', type: 'number' },
          { key: 'intro', label: '简介', type: 'textarea' },
          { key: 'content', label: '做法', type: 'textarea' },
          { key: 'detail_image_keys', label: '详情图 JSON', type: 'json' },
          { key: 'created_at', label: '创建时间', type: 'datetime' },
          { key: 'updated_at', label: '更新时间', type: 'datetime' },
        ],
      },
      {
        key: 'recipe_ingredient_tags',
        label: '食材标签',
        description: '维护菜谱与食材标签关系。',
        fields: [
          { key: 'recipe_id', label: '菜谱', type: 'number' },
          { key: 'tag_id', label: '主料标签', type: 'number' },
        ],
      },
      {
        key: 'recipe_sauce_tags',
        label: '酱料标签',
        description: '维护菜谱与酱料标签关系。',
        fields: [
          { key: 'recipe_id', label: '菜谱', type: 'number' },
          { key: 'tag_id', label: '调味标签', type: 'number' },
        ],
      },
      {
        key: 'recipe_flavor_tags',
        label: '口味标签',
        description: '维护菜谱与口味标签关系。',
        fields: [
          { key: 'recipe_id', label: '菜谱', type: 'number' },
          { key: 'tag_id', label: '风味标签', type: 'number' },
        ],
      },
      {
        key: 'wish_items',
        label: '想做清单',
        description: '维护待做菜谱列表。',
        idKey: 'id',
        fields: [
          { key: 'id', label: 'ID', type: 'number' },
          { key: 'day_key', label: '日期', type: 'number' },
          { key: 'recipe_id', label: '菜谱', type: 'number' },
          { key: 'created_at', label: '创建时间', type: 'datetime' },
        ],
      },
      {
        key: 'meals',
        label: '用餐计划',
        description: '维护每日餐次和备注。',
        idKey: 'id',
        fields: [
          { key: 'id', label: 'ID', type: 'number' },
          { key: 'day_key', label: '日期', type: 'number' },
          { key: 'meal_tag_id', label: '餐次', type: 'number' },
          { key: 'note', label: '备注', type: 'textarea' },
          { key: 'sort_index', label: '排序', type: 'number' },
          { key: 'created_at', label: '创建时间', type: 'datetime' },
          { key: 'updated_at', label: '更新时间', type: 'datetime' },
        ],
      },
      {
        key: 'meal_items',
        label: '餐次菜谱',
        description: '维护餐次与菜谱关系。',
        fields: [
          { key: 'meal_id', label: '餐次', type: 'number' },
          { key: 'recipe_id', label: '菜谱', type: 'number' },
          { key: 'sort_index', label: '排序', type: 'number' },
          { key: 'created_at', label: '创建时间', type: 'datetime' },
        ],
      },
      {
        key: 'meal_item_ratings',
        label: '餐次评分',
        description: '维护餐次评分结果。',
        idKey: 'id',
        fields: [
          { key: 'id', label: 'ID', type: 'number' },
          { key: 'meal_id', label: '餐次', type: 'number' },
          { key: 'recipe_id', label: '菜谱', type: 'number' },
          { key: 'rating', label: '评分', type: 'number' },
          { key: 'created_at', label: '创建时间', type: 'datetime' },
        ],
      },
    ],
  },
  tag_manager: {
    id: 'tag_manager',
    name: '标签管理',
    description: '统一管理通用标签和工具标签。',
    accentClassName: 'from-violet-400/25 via-violet-300/5 to-white',
    sections: [
      {
        key: 'tags',
        label: '标签',
        description: '维护公共标签基础信息。',
        idKey: 'id',
        fields: [
          { key: 'id', label: 'ID', type: 'number' },
          { key: 'name', label: '名称', type: 'text' },
          { key: 'color', label: '颜色', type: 'number' },
          { key: 'sort_index', label: '排序', type: 'number' },
          { key: 'created_at', label: '创建时间', type: 'datetime' },
          { key: 'updated_at', label: '更新时间', type: 'datetime' },
        ],
      },
      {
        key: 'tool_tags',
        label: '工具标签',
        description: '维护工具分类与标签关系。',
        fields: [
          { key: 'tool_id', label: '工具', type: 'text' },
          { key: 'tag_id', label: '标签', type: 'number' },
          { key: 'category_id', label: '分类', type: 'text' },
          { key: 'sort_index', label: '排序', type: 'number' },
        ],
      },
    ],
  },
  app_config: {
    id: 'app_config',
    name: '应用配置',
    description: '集中维护 AI、同步、对象存储与全局设置。',
    accentClassName: 'from-cyan-400/25 via-sky-300/5 to-white',
    sections: [
      {
        key: 'ai_config',
        mode: 'single',
        label: 'AI 配置',
        description: '管理大模型服务地址、模型参数与鉴权信息。',
        fields: [
          { key: 'baseUrl', label: 'Base URL', type: 'text' },
          { key: 'model', label: '模型', type: 'text' },
          { key: 'temperature', label: '温度', type: 'number' },
          { key: 'maxOutputTokens', label: '最大输出 Token', type: 'number' },
          { key: 'apiKey', label: 'API Key', type: 'textarea', sensitive: true },
        ],
      },
      {
        key: 'sync_config',
        mode: 'single',
        label: '同步配置',
        description: '管理同步用户、服务端地址与网络策略。',
        fields: [
          { key: 'userId', label: '用户 ID', type: 'text' },
          { key: 'networkType', label: '网络类型', type: 'number', defaultValue: 0 },
          { key: 'serverUrl', label: '服务端地址', type: 'text' },
          { key: 'serverPort', label: '服务端端口', type: 'number', defaultValue: 443 },
          { key: 'autoSyncOnStartup', label: '启动时自动同步', type: 'boolean', defaultValue: true },
          { key: 'lastSyncTime', label: '上次同步时间', type: 'datetime' },
          { key: 'lastServerRevision', label: '上次服务端版本', type: 'number' },
          {
            key: 'allowedWifiNames',
            label: '允许 Wi-Fi JSON',
            type: 'json',
            defaultValue: [],
          },
          {
            key: 'customHeaders',
            label: '自定义请求头 JSON',
            type: 'json',
            defaultValue: {},
            sensitive: true,
          },
        ],
      },
      {
        key: 'obj_store_config',
        mode: 'single',
        label: '对象存储配置',
        description: '管理对象存储提供方、域名、Bucket 与上传策略。',
        fields: [
          { key: 'type', label: '存储类型', type: 'text' },
          { key: 'bucket', label: 'Bucket', type: 'text' },
          { key: 'domain', label: '访问域名', type: 'text' },
          { key: 'uploadHost', label: '上传地址', type: 'text' },
          { key: 'keyPrefix', label: 'Key 前缀', type: 'text' },
          { key: 'qiniuIsPrivate', label: '七牛私有空间', type: 'boolean' },
          { key: 'qiniuUseHttps', label: '七牛 HTTPS', type: 'boolean' },
          { key: 'dataCapsuleBucket', label: '数据胶囊 Bucket', type: 'text' },
          { key: 'dataCapsuleEndpoint', label: '数据胶囊 Endpoint', type: 'text' },
          { key: 'dataCapsuleDomain', label: '数据胶囊域名', type: 'text' },
          { key: 'dataCapsuleRegion', label: '数据胶囊 Region', type: 'text' },
          { key: 'dataCapsuleKeyPrefix', label: '数据胶囊 Key 前缀', type: 'text' },
          { key: 'dataCapsuleIsPrivate', label: '数据胶囊私有', type: 'boolean' },
          { key: 'dataCapsuleUseHttps', label: '数据胶囊 HTTPS', type: 'boolean' },
          { key: 'dataCapsuleForcePathStyle', label: '强制 Path Style', type: 'boolean' },
        ],
      },
      {
        key: 'obj_store_secrets',
        mode: 'single',
        label: '对象存储密钥',
        description: '维护对象存储 Access Key / Secret Key 等敏感信息。',
        fields: [
          { key: 'accessKey', label: 'Access Key', type: 'text', sensitive: true },
          { key: 'secretKey', label: 'Secret Key', type: 'textarea', sensitive: true },
        ],
      },
      {
        key: 'ai_call_history',
        mode: 'single',
        label: 'AI 调用历史',
        description: '查看历史保留策略与最近调用记录。',
        fields: [
          { key: 'retention_limit', label: '保留条数', type: 'number', defaultValue: 5 },
          { key: 'records', label: '调用记录 JSON', type: 'json', defaultValue: [] },
        ],
      },
      {
        key: 'settings',
        mode: 'single',
        label: '应用设置',
        description: '维护默认工具、工具排序、隐藏列表与主题模式。',
        fields: [
          { key: 'default_tool_id', label: '默认工具', type: 'text' },
          { key: 'theme_mode', label: '主题模式', type: 'text', defaultValue: 'light' },
          { key: 'tool_order', label: '工具排序 JSON', type: 'json', defaultValue: [] },
          { key: 'hidden_tool_ids', label: '隐藏工具 JSON', type: 'json', defaultValue: [] },
        ],
      },
    ],
  },
};

export function getToolConfig(toolId: string): ToolConfig {
  return (
    toolConfigs[toolId] ?? {
      id: toolId,
      name: toolId,
      description: '当前工具使用通用数据管理模式。',
      accentClassName: 'from-slate-300/20 via-slate-300/5 to-white',
      sections: [],
    }
  );
}

export function getSectionConfig(toolId: string, sectionKey: string) {
  return getToolConfig(toolId).sections.find((item) => item.key === sectionKey);
}
