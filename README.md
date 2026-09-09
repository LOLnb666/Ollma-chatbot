
# 家具官网（WordPress）

仓库包含一键本地安装脚本。脚本会安装 PHP 8.2、MySQL、Apache 和
WP-CLI，创建 `FURNITURE` 数据库，下载最新版简体中文 WordPress，并将站点
标题设置为“家具官网”。

## 安装

在 Ubuntu 环境中从项目根目录执行：

```bash
sudo ./scripts/install-wordpress.sh
```

默认后台地址为 <http://localhost/wp-admin/>，默认管理员账号为
`furniture_admin`。脚本会随机生成管理员密码和数据库密码，并将完整登录信息
写入仅本机可读且已被 Git 忽略的 `.wordpress-credentials` 文件：

```bash
cat .wordpress-credentials
```

可以在首次运行时通过环境变量覆盖默认值，例如：

```bash
sudo WP_URL=http://furniture.local \
  WP_ADMIN_USER=my_admin \
  WP_ADMIN_PASSWORD='请替换为强密码' \
  WP_ADMIN_EMAIL=admin@example.com \
  ./scripts/install-wordpress.sh
```

> 安装过程需要访问 Ubuntu 软件源、WordPress.org 和 GitHub，并需要能够使用
> `systemctl` 启动 MySQL 与 Apache。
