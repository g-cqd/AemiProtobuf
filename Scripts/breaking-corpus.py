import os, json, subprocess
base=open('base.proto').read()
variants = {
 'remove-field': base.replace('  optional string b = 2;\n',''),
 'remove-field-reserved': base.replace('  optional string b = 2;\n','  reserved 2;\n'),
 'type-incompatible': base.replace('optional int32 a = 1;','optional string a = 1;'),
 'type-compatible': base.replace('optional int32 a = 1;','optional int64 a = 1;'),
 'rename-field': base.replace('optional int32 a = 1;','optional int32 renamed = 1;'),
 'into-oneof': base.replace('  optional int32 z = 9;\n','').replace('string y = 8; }','string y = 8; int32 z = 9; }'),
 'cardinality': base.replace('repeated int32 c = 3;','optional int32 c = 3;'),
 'required-to-optional': base.replace('required int32 r = 5;','optional int32 r = 5;'),
 'remove-enum-value': base.replace(' MID = 2;',''),
 'remove-enum-value-reserved': base.replace(' MID = 2;',' reserved 2;'),
 'remove-message': base.replace('message Gone { optional int32 g = 1; }\n',''),
 'remove-reserved-range': base.replace('  reserved 100 to 110;\n',''),
 'json-name': base.replace('[json_name = "jay"]','[json_name = "jj"]'),
 'use-reserved-number': base.replace('  reserved 100 to 110;\n','  reserved 101 to 110;\n  optional int32 extra = 100;\n'),
}
cfg='{"version":"v2","breaking":{"use":["WIRE"]}}'
results={}
for name,text in variants.items():
    os.makedirs(f'{name}/old',exist_ok=True); os.makedirs(f'{name}/new',exist_ok=True)
    open(f'{name}/old/bc.proto','w').write(base); open(f'{name}/new/bc.proto','w').write(text)
    for side in ('old','new'):
        subprocess.run(['protoc',f'-I{name}/{side}',f'--descriptor_set_out={name}-{side}.pb','bc.proto'],check=True)
    r=subprocess.run(['buf','breaking',f'{name}-new.pb#format=binpb','--against',f'{name}-old.pb#format=binpb','--config',cfg,'--error-format','json'],capture_output=True,text=True)
    rules=sorted({json.loads(l)['type'] for l in r.stdout.splitlines() if l.strip()})
    results[name]=rules
    if r.returncode not in (0,100): print(name, 'ERR', r.returncode, r.stderr[:300])
for k,v in results.items(): print(f"{k:28s} {v}")
json.dump(results, open('expected.json','w'), indent=1, sort_keys=True)
