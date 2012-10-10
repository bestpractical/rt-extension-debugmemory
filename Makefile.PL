use inc::Module::Install;


RTx 'RT-Extension-DebugMemory';
all_from 'lib/RT/Extension/DebugMemory.pm';
readme_from 'lib/RT/Extension/DebugMemory.pm';
license  'gplv2';

requires 'Plack::Middleware::GTop::ProcMem';

sign;
WriteAll;
