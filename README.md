# DataAnalyticsPortfolio
Привет! Меня зовут Эрденко Ева, я начинающий аналитик данных. Здесь собраны мои пет-проекты в целях демонстрации знаний и навыков.

### Проект№1: ETL данных о пятидневном прогнозе погоды
В данном проекте я написала Jupyter notebook на python для сбора данных о прогнозе погоды в Москве с помощью API openweathermap.org. Далее я очистила и преобразовала полученные данные для дальнейшей загрузки в облачное PostgreSQL хранилище TimeWeb и использовала JupyterLab для автоматизации своего ноутбука. В заключении я создала интерактивный дашборд в PowerBI для доступной и увлекательной визуализации полученных данных 

Инструменты: Pandas, Numpy, API, requests, PostgreSQL, PowerBI, Jupyter Notebook, Jupyter Lab

[Таблица в облачном хранилище](https://dbs.timeweb.com/?pgsql=85.193.89.81&username=gen_user&password=Stpof3552&db=default_db&ns=public&select=weather_forcast_5day)


[Дашборд в PowerBI](Weather5dayForcastDashboard.pbix)


[Код, Jupyter Notebook](WeatherData.ipynb)

![WeatherForcastDashboardScreenshot](https://github.com/user-attachments/assets/8a5c452f-af9a-4e9c-a543-b474c4724209)

### Проект№2: Расчет продуктовых метрик и когортный анализ для онлайн магазина электороники
В данном проекте я рассчитала такие ключевые продуктовые метрики как MAU, WAU, DAU sticky factor, ARPU и LTV с помощью PostgreSQL. Провела ABC-XYZ анализ продуктов, а также когортный анализ retention.

Инструменты: CTEs, Views, joins, Window Functions, Aggregate Functions, Type convertion

[Код, PostgreSQL](SQLSessionsAnalysisProject.sql)


