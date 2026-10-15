#!/usr/bin/env python3
"""Generate fictional Sport CSV v1, without personal data or private photos."""
import csv, io, json, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COLUMNS = 'sport_csv_version row_type workout_id workout_name date status schedule_id started_at_ms ended_at_ms rest_seconds exercise_id catalogue_id exercise_name mode set_count min_reps max_reps duration_target_seconds feeling set_id set_number repetitions duration_seconds weight_kg completed_at_ms components_json goal_json pending_start_ms pending_weight_kg pending_end_ms pending_components_json'.split()
rows = []
first = datetime.date(2026, 1, 12)
last = datetime.date(2026, 10, 11)
loads = ['0', '3.9', '4.5', '5.1']
workouts = 0
for offset in range((last-first).days+1):
    day = first + datetime.timedelta(days=offset)
    if day.isoweekday() not in (2, 6, 7):
        continue
    workouts += 1
    week = offset//7
    exercises = [('bulgarians', 'Bulgarians', 'repetitions')] if day.isoweekday()==2 else [('push-ups', 'Push-ups', 'repetitions'),('pike-push-ups','Pike Push-ups','repetitions')] if day.isoweekday()==6 else [('chin-ups','Chin-ups','repetitions'),('l-sit','L-sit','duration')]
    wid = f'demo-2026-{day.isoformat()}'
    started = int(datetime.datetime.combine(day, datetime.time(17,30), datetime.timezone.utc).timestamp()*1000)
    cancelled = workouts % 17 == 0
    status = 'cancelled' if cancelled else 'completed'
    end = started + (36 if len(exercises)==2 else 18)*60000
    for position,(catalogue,name,mode) in enumerate(exercises):
        exid = f'{wid}-ex-{position}'
        set_total = 2 if cancelled and position==0 else 0 if cancelled else 4
        weight = loads[min(week//10, 3)] if mode=='repetitions' else loads[min(week//16,2)]
        for number in range(1,max(1,set_total)+1):
            values = dict.fromkeys(COLUMNS,'')
            values.update(sport_csv_version='1',row_type='set' if set_total else 'exercise', workout_id=wid, workout_name='DEMO · '+('Legs' if len(exercises)==1 else 'Push' if day.isoweekday()==6 else 'Pull + Abs'), date=day.isoformat(),status=status,schedule_id='demo-'+str(day.isoweekday()),started_at_ms=str(started),ended_at_ms=str(end),rest_seconds='180',exercise_id=exid,catalogue_id=catalogue,exercise_name=name,mode=mode,set_count='4',min_reps='8' if mode=='repetitions' else '',max_reps='12' if mode=='repetitions' else '',feeling='' if cancelled else '7.3' if workouts%23==0 else '7.9' if workouts%29==0 else '7.5' if week%10>=8 else '8.0' if week%4==1 else '6.5')
            if set_total:
                rep = min(12,8+week%10//2-(number-1)//3)
                if week>=37: rep=12
                values.update(set_id=f'{exid}-set-{number}',set_number=str(number),repetitions=str(rep) if mode=='repetitions' else '',duration_seconds=f'{12+week*0.6-(number-1)*0.8:.3f}' if mode=='duration' else '',weight_kg=weight,completed_at_ms=str(started+(position*4+number)*240000))
                if weight=='0': values['components_json']='[]'
                elif weight=='3.9': values['components_json']=json.dumps([{'id':'base-bag','name':'Sac','grams':3000},{'id':'river-book','name':'La rivière à l’envers','grams':900}],ensure_ascii=False,separators=(',',':'))
            rows.append([values[column] for column in COLUMNS])
stream=io.StringIO(newline='')
writer=csv.writer(stream,lineterminator='\r\n',quoting=csv.QUOTE_ALL)
writer.writerow(COLUMNS);writer.writerows(rows)
data=('\ufeff'+stream.getvalue()).encode('utf-8')
for file in [ROOT/'docs/fixtures/Sport-demo-2026.csv',ROOT/'Sources/Sport/Resources/Sport-demo-2026.csv']:
    file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(data)
print(f'Fictional fixture: {workouts} workouts, {sum(r[1]=="set" for r in rows)} sets, {len(data)} bytes, 2026-01-13 to {last}.')
