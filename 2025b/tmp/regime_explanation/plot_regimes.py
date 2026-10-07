from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

out = Path(__file__).parent
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 11})
fig, axes = plt.subplots(1, 2, figsize=(13, 5.6), layout='constrained')
x = np.linspace(0, 1.5, 601)
left = np.linspace(0, 1, 401)
right = np.linspace(1, 1.5, 201)
blue, orange = '#2166ac', '#d66020'
ax = axes[0]
ax.plot(x, x**3, '--', color=blue, alpha=.4, label='Формула плато: y = x³')
ax.plot(x, x, '--', color=orange, alpha=.4, label='Вязкая формула: y = x')
ax.plot(left, left**3, color=blue, lw=3.5)
ax.plot(right, right, color=orange, lw=3.5)
ax.scatter([1], [1], color='#202c3c', s=45, zorder=5)
ax.annotate('Одинаковый расход\nОбе формулы дают y = 1', xy=(1,1), xytext=(.1,2.1),
            arrowprops={'arrowstyle':'->','color':'#202c3c'}, fontsize=11)
ax.set(title='Расход непрерывен: ветви встречаются', ylabel='Расход  y = Q / Qкр', ylim=(0,3.5))
ax.legend(loc='upper left', fontsize=10)
ax.text(.04,.04,'Толстая линия — выбранная в модели ветвь.\nПунктир — продолжение формул за пределами их режима.',
        transform=ax.transAxes, fontsize=9, bbox={'facecolor':'white','edgecolor':'none','alpha':.9})
ax = axes[1]
ax.plot(left[:-1], 3*left[:-1]**2, color=blue, lw=3.5)
ax.plot(right[1:], np.ones(len(right)-1), color=orange, lw=3.5)
ax.scatter([1,1],[3,1],s=65,facecolors='white',edgecolors=[blue,orange],linewidths=2,zorder=5)
ax.annotate('',xy=(1.08,3),xytext=(1.08,1),arrowprops={'arrowstyle':'<->','color':'#202c3c'})
ax.text(1.12,2,'Наклон\nменяется\nв 3 раза',va='center',fontsize=10)
ax.text(.14,2.55,'Слева: наклон → 3',color=blue)
ax.text(.75,.65,'Справа: наклон = 1',color=orange)
ax.set(title='Наклон меняется скачком: это излом', ylabel='Наклон графика расхода  dy / dx', ylim=(0,3.5))
for ax in axes:
    ax.set_xlim(0,1.5)
    ax.set_xlabel('Избыток давления  x = (Δp − Pc) / dкр')
    ax.axvline(1,color='#89929e',lw=1,ls=':',zorder=0)
    ax.grid(alpha=.18)
    ax.spines[['top','right']].set_visible(False)
fig.suptitle('Два режима при фиксированной насыщенности и Aeff > 0',fontsize=16)
fig.savefig(out/'regimes.png',dpi=170)
fig.savefig(out/'regimes.svg')
